#!/bin/bash
#
# This script intents to provide a tool
# to send secure (PGP-encrypted) mail.
#
# It can be used to write script that reports via mail.

set -e

WORK_DIR=$(mktemp -d)

# File that contains the whole mail that will passed to sendmail
MAIL_FILE=$WORK_DIR/mail
# File that contains the encrypted content and attachments of the mail
ENCRYPTED_MAIL_FILE=$WORK_DIR/encryped_mail

PGP_BOUNDARY=qwerty1234_pgp
CONTENT_BOUNDARY=qwerty1243_mail

SUBJECT=''
RECIPIENT=''
BODY_FILE=''
FROM=''


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
    echo $1
    die 1
}

## Print usage and die
## $1 is status code
function usage()
{
    echo "Usage: ${0} -r=|--recipient= -f=|--from= -b=|--body= [-s=|--subject=] [Attachment file]*"
    echo "Recipient of the mail. Only is supported."
    echo "Sender of the mail. Must be set"
    echo "Path to the file containing the plain/text body of the mail"
    echo "Subject of mail. This will NOT be encrypted"
    echo "Path to attachements files"
    die $1
}

## Write base mail header to the mail file, erasing
## any previous content.
## Thoses state that our mail is a encrypted pgp mail.
function write_clear_header()
{
    printf '%s\n' "
Subject: ${SUBJECT}
Mime-Version: 1.0
From: ${FROM}
To: ${RECIPIENT}
Content-Type: multipart/encrypted; boundary=$PGP_BOUNDARY; protocol=application/pgp-encrypted;
Content-Transfer-Encoding: 7bit
Content-Description: OpenPGP encrypted message
 
This is an OpenPGP/MIME encrypted message (RFC 2440 and 3156)
--${PGP_BOUNDARY}
Content-Transfer-Encoding: 7bit
Content-Type: application/pgp-encrypted
Content-Description: PGP/MIME Versions Identification
 
Version: 1
 
--${PGP_BOUNDARY}
Content-Transfer-Encoding: 7bit
Content-Disposition: inline
Content-Type: application/octet-stream
Content-Description: OpenPGP encrypted message

" > $MAIL_FILE
}

## Write the body of the mail
## $1 is the path to the file to include in the body.
## It must be a text file.
function write_body()
{
    printf '%s\n' "Content-Type: multipart/mixed; boundary=${CONTENT_BOUNDARY}

--${CONTENT_BOUNDARY}
Content-Type: text/plain; charset=UTF-8
Content-Disposition: inline
"
    cat $1 >> $ENCRYPTED_MAIL_FILE
}


# Add attachment (will encode in base64) to the CLEAR_MAIL file
# $1 is path to the file
function add_attachment()
{
    filename="{$1##*/}"
    printf '%s\n' "--${CONTENT_BOUNDARY}
Content-Type:`file --mime-type $1 | cut -d':' -f2`
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=\"${filename}\"
X-Attachment-Id: f_`uuidgen | cut -d'-' -f1`
" >> $ENCRYPTED_MAIL_FILE

    base64 $1 >> $ENCRYPTED_MAIL_FILE
}

for i in "$@"
do
    case $i in
	-r=*|--subject=*)
	RECIPIENT="${i#*=}"
	shift
	;;
	-s=*|--subject=*)
	SUBJECT="${i#*=}"
	shift
	;;
	-b=*|--body=*)
	BODY_FILE="${i#*=}"
	shift
	;;	
	-f=*|--from=*)
	FROM="${i#*=}"
	shift
	;;
	-h|\?|--help)
	    usage 0;
	;;
	*)
            # unknown option
	    usage 1
	;;
    esac
done

[ ! -z $RECIPIENT ] || fail "Recipient must be set";
[ ! -z $FROM ] || fail "Sender must be set";



die 0