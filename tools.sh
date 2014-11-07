#!/bin/bash
#
# General use function that are reused throughout scripts.
# This file should be sourced.

RCol='\e[0m'    # Text Reset
Bla='\e[0;30m';
Red='\e[0;31m';
Gre='\e[0;32m';
Yel='\e[0;33m';
Blu='\e[0;34m';

## Write $@ to stderr
function errcho()
{
    >&2 echo "$@"
}

## Perform cleanup and exit.
## $1 is status code. If not set returns 1
function die()
{
    rm -rf ${WORK_DIR}
    [ ! -z $1 ] && exit $1
    exit 1
}

## Print an error message and die
## $1 is the error message
function fail()
{
    echo "Exiting due to fatal error:" $1
    die 1
}

## Check that the system / environment
## meet some requirements before running.
## This is helpful when running from cron
function check_requirement()
{
    error=0
    if [ -z "`which btrfs`" ] ; then
	echo -e "[${Red} KO ${RCol}] Cannot find btrfs binary: attempting to fix by
	adding /sbin/ to PATH"
	export PATH="/sbin/:$PATH"
	error=1
    fi

    if [ $USE_SSMTP -eq 1 ] && [ -z "`which ssmtp`" ] ; then
	echo -e "[${Red} KO ${RCol}] Cannot find ssmtp binary: attempting to fix by
	adding /usr/sbin/ to PATH"
	export PATH="/usr/sbin/:$PATH"
	error=1
    fi

    return $error
}

if check_requirement ; then
    echo "Some requirement failed. Trying again to see if autofix worked"
    check_requirement || fail "Requirement checking failed again"
fi
