#!/bin/bash
#
# Send various info

TMP_DIR=$(mktemp -d)
MESSAGE_FILE=$TMP_DIR/message_file


function btrfs_info()
{
    printf "%s\n" "
    ---------------------------------------
    BTRFS REPORTING
    ---------------------------------------" >> $MESSAGE_FILE

    printf "%s\n" "**btrfs show**" >> $MESSAGE_FILE
    btrfs fi show >> $MESSAGE_FILE

    printf "%s\n" "**btrfs df**" >> $MESSAGE_FILE
    btrfs fi df / >> $MESSAGE_FILE

    echo "\nWe have" $(btrfs sub list / | wc -l) "btrfs subvolumes/snapshots" >> $MESSAGE_FILE
}

function load_info()
{
    printf "%s\n\n" "
    ---------------------------------------
    LOAD REPORTING
    ---------------------------------------" >> $MESSAGE_FILE

    echo "Uptime: " $(uptime) >> $MESSAGE_FILE
}

echo -e "General system report, ran `date`.\n" >> $MESSAGE_FILE

btrfs_info
load_info

source config.sh

( ./secure_mail.sh -r=${ADMIN_MAIL} -rk=${ADMIN_PGP_KEY} -f=${SOURCE_MAIL} \
    -b=$MESSAGE_FILE -s="System Status Script Report" \
    --passphrase=$SIGNING_KEY_PASSPHRASE --assume-yes) || fail "Mail send error"
