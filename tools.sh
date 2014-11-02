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
