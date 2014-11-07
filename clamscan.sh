#!/bin/bash
#
# Run clamscan and send the report via a secure mail

set -e

WORK_DIR=$(mktemp -d)
TIME_TAKEN_FILE=$WORK_DIR/time_taken
CLAM_REPORT_FILE=$WORK_DIR/report_file.txt
MESSAGE_FILE=$WORK_DIR/message_file
DIR_TO_SCAN=()

SCRIPT_DIR=`dirname "$0"`
source $SCRIPT_DIR/config.sh
source $SCRIPT_DIR/tools.sh

function check_input()
{
    for dir in "$@";
    do
	echo -en ${RCol}
	target=''
	if [ -z "$dir" ] ; then
	    fail "Invalid directory"
	fi

	if [ `echo $dir | cut -c1-1` = "/" ] ; then
	    target="$dir"
	else
	    target="`pwd`/$dir"
	fi

	DIR_TO_SCAN+=($target)
	echo -e "Will run clamscan over: ${Yel}$target"
    done

    echo -en ${RCol}
    if [ -z $CLAMSCAN_SH_ASSUME_YES ] || [ $CLAMSCAN_SH_ASSUME_YES != "true" ]; then
	echo -n "Press y to continue: "
	read user_input
	if [ $? -ne 0 ]; then
	    return 1;
	fi
	if [ ! -z $user_input ] && { [ $user_input = "y" ] || [ $user_input = "Y" ] ; } ; then
	    return 0;
	fi
	return 1;
    fi
    echo "Skipping manual confirmation..."
    return 0
}

## write mail body content
function write_body()
{
    printf "%s\n" "This is a ClamScan report. It was generated by clamscan.sh, and ran
at this date: `date`.
Time for the script to run: `cat $TIME_TAKEN_FILE`
${#DIR_TO_SCAN[@]} directories scanned:
" >> $MESSAGE_FILE
    for dir in ${DIR_TO_SCAN[@]};
    do
	echo -e "\t $dir" >> $MESSAGE_FILE
    done
    echo "Full report is available as an attachment." >> $MESSAGE_FILE
}

# Add the summary of the scan (found in $CLAM_REPORT_FILE) to $MESSAGE_FILE
function add_scan_summary_to_body()
{
    echo "Below is the scan summary:" >> $MESSAGE_FILE
    ## see http://stackoverflow.com/questions/7103531/how-to-get-the-part-of-file-after-the-line-that-matches-grep-expression-first
    sed -e '1,/----------- SCAN SUMMARY -----------/d' $CLAM_REPORT_FILE >> $MESSAGE_FILE
}

function usage()
{
    echo "./$0 DIR1 [DIRN]"
    echo "Environement variable to drive behaviour:"
    echo -e "\t CLAMSCAN_SH_ASSUME_YES: If set to true, will not ask for confirmation before running"
}

function main()
{
    if [ $# -lt 1 ]; then
	echo "Failed invocation: too few arguments"
	usage
	fail
    fi

    check_input "$@"
    if [ $? -eq 1 ]; then
	fail "Canceled by user"
    fi

    echo "Continuing... (tmpfile = $WORK_DIR)"


    additional_body=''
    ionice_cmd=''
    if [ ${IONICE_LEVEL} = "IDLE" ]; then
	ionice_cmd='ionice -c 3';
    else
	if [ ! -z ${IONICE_LEVEL} ]; then
	    ionice_cmd='ionice -c 2 -n ${IONICE_LEVEL}'
	fi
    fi

    echo "Nice and ionice cmd:" $ionice_cmd nice -n ${NICE_LEVEL}
    {  time $ionice_cmd nice -n ${NICE_LEVEL} clamscan -vr "$@" >> $CLAM_REPORT_FILE ; } 2> $TIME_TAKEN_FILE \
	|| { echo "Non 0 return code from Clamscan"; \
	additional_body="Error in scan (or viruses)" ; }

    write_body
    [ ! -z additional_body ] && echo $additional_body >> $MESSAGE_FILE

    add_scan_summary_to_body

    ( ./secure_mail.sh -r=${ADMIN_MAIL} -rk=${ADMIN_PGP_KEY} -f=${SOURCE_MAIL} \
	-b=$MESSAGE_FILE -s="ClamScan Script Report" \
	--passphrase=$SIGNING_KEY_PASSPHRASE --assume-yes -- $CLAM_REPORT_FILE ) || fail "Mail send error"
    return 0
}

main "$@"
die $?
