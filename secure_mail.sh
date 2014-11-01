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

# File that contains the content and attachments of the mail.
# This file will be encrypted before being sent
CONTENT_MAIL_FILE=$WORK_DIR/content_mail

# Encrypted content
ENCRYPTED_MAIL_FILE=$WORK_DIR/encryped_mail

PGP_BOUNDARY=qwerty1234_pgp
CONTENT_BOUNDARY=qwerty1243_mail

ASSUME_YES=0
SIGNING_KEY_PASSPHRASE=''

SUBJECT=''
RECIPIENT=''
BODY_FILE=''
FROM=''
ATTACHMENTS=()

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
    echo $1
    die 1
}

## Print usage and die
## $1 is status code
function usage()
{
    echo "Usage: ${0} -r=|--recipient= -f=|--from= -b=|--body= -rk|--recipient-key= \
[-s=|--subject=] [=-p|--passphrase=] -- [Attachment file]*"
    echo "Recipient of the mail. Only is supported."
    echo "Sender of the mail. Must be set"
    echo "Path to the file containing the plain/text body of the mail"
    echo "GPG key id of recipient"
    echo "Passphrase of our signing key"
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
    [ -r $1 ] || fail "Body file is not readable: $1"
    
    printf '%s\n' "Content-Type: multipart/mixed; boundary=${CONTENT_BOUNDARY}

--${CONTENT_BOUNDARY}
Content-Type: text/plain; charset=UTF-8
Content-Disposition: inline
" >> $CONTENT_MAIL_FILE
    cat $1 >> $CONTENT_MAIL_FILE
}


# Add attachment (will encode in base64) to the CLEAR_MAIL file
# $1 is path to the file
function add_attachment()
{
    [ -r $1 ] || fail "attachment file is not readable: $1"
    filename="{$1##*/}"
    printf '%s\n' "--${CONTENT_BOUNDARY}
Content-Type:`file --mime-type $1 | cut -d':' -f2`
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=\"${filename}\"
X-Attachment-Id: f_`uuidgen | cut -d'-' -f1`
" >> $CONTENT_MAIL_FILE

    base64 $1 >> $CONTENT_MAIL_FILE
}

## Encrypt $1 and write to $2
function encrypt()
{
    if [ $ASSUME_YES -eq 1 ]; then
	cat $1 | gpg --batch --yes --passphrase=$SIGNING_KEY_PASSPHRASE --encrypt --sign \
	    --armor --recipient $RECIPIENT_KEY > $2
    else
	cat $1 | gpg --encrypt --sign --armor --recipient $RECIPIENT_KEY > $2
    fi
    return 0
}

## Build the mail and write the result to $MAIL_FILE
function compose_mail()
{
    write_body $BODY_FILE
    for attachment in ${ATTACHMENTS[@]}; do
	add_attachment $attachment
    done
    
    echo "--${CONTENT_BOUNDARY}--" >> $CONTENT_MAIL_FILE
    
    ( encrypt $CONTENT_MAIL_FILE $ENCRYPTED_MAIL_FILE ) | cat >> $MAIL_FILE
    # check result of encrypt
    [ ${PIPESTATUS[0]} -eq 0 ] || fail "Encryption failed"

    echo "--${PGP_BOUNDARY}--" >> $MAIL_FILE
}

## Prints what's about to be done and ask for user confirmation 
## unless ASSUME_YES is set to 1.
function confirm()
{
    if [ $ASSUME_YES -eq 1 ] ; then
	echo "Skipping confirmation"
	return 0;
    fi

    printf  "%s\n" "Mail info:
    to: $RECIPIENT
    from: $FROM
    subject: $SUBJECT
    body-file: $BODY_FILE
    attachments:"

    for attachment in ${ATTACHMENTS[@]}
    do
	echo -e "\t\t" $attachment
    done

    return 0
}

for i in "$@"
do
    case $i in
	-r=*|--subject=*)
	RECIPIENT="${i#*=}"
	shift
	;;
	-rk=*|--recipient-key=*)
	RECIPIENT_KEY="${i#*=}"
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
	-p=*|--passphrase=*)
	SIGNING_KEY_PASSPHRASE="${i#*=}"
	shift
	;;	
	-f=*|--from=*)
	FROM="${i#*=}"
	shift
	;;
	-h|\?|--help)
	    usage 0;
	    ;;
	--)
	    read_attachment_files=1
	    ;;
	*)
	    ## unkown option or attachment file
	    [ $read_attachment_files -eq 1 ] || usage 1
	    ATTACHMENTS+=($i)
	;;
    esac
done

[ ! -z $RECIPIENT ] || fail "Recipient must be set";
[ ! -z $FROM ] || fail "Sender must be set";
[ ! -z $BODY_FILE ] || fail "Body file must be set";
[ ! -z $RECIPIENT_KEY ] || fail "Recipient key must be set";

compose_mail
    
confirm || { echo "Canceled by user"; die 0 ; }

die 0