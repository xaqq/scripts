#!/bin/bash
#
# Define interresting configuration variable.
# This file is sourced by other scripts

ADMIN_MAIL=''
ADMIN_PGP_KEY=''
SOURCE_MAIL=''
SIGNING_KEY_PASSPHRASE=''

NICE_LEVEL=20

## Ionice info. Either idle or ignored
IONICE_LEVEL=IDLE

## Use the ssmtp binary to send report mail.
USE_SSMTP='1'
