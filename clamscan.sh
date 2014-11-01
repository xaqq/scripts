#!/bin/bash
#
# Run clamscan and send the report via a secure mail

set -e

RCol='\e[0m'    # Text Reset
Bla='\e[0;30m';
Red='\e[0;31m';
Gre='\e[0;32m';
Yel='\e[0;33m';
Blu='\e[0;34m';

TMP_DIR=$(mktemp -d)
TIME_TAKEN_FILE=$TMP_DIR/time_taken
CLAM_REPORT_FILE=$TMP_DIR/report_file.txt
MESSAGE_FILE=$TMP_DIR/message_file
DIR_TO_SCAN=()

# $1 is the message to print
function fail()
{
    echo "$1"
    echo -en ${RCol}
    exit -1
}

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

    source config.sh
    
    check_input "$@"
    if [ $? -eq 1 ]; then
	fail "Canceled by user"
    fi
    
    echo "Continuing... (tmpfile = $TMP_DIR)"

    
    write_body
    
    { time clamscan -vr "$@" >> $CLAM_REPORT_FILE ; } 2> $TIME_TAKEN_FILE
    if [ ! $? -eq 0 ]; then
	echo "Error"
	echo "Error in scan (or viruses)" >> $MESSAGE_FILE
    fi
    
    add_scan_summary_to_body

    ( ./secure_mail.sh -r=${ADMIN_MAIL} -rk=${ADMIN_PGP_KEY} -f=${SOURCE_MAIL} \
	-b=$MESSAGE_FILE -s="ClamScan Script Report" \
	--passphrase=$SIGNING_KEY_PASSPHRASE --assume-yes -- $CLAM_REPORT_FILE ) || fail "Mail send error"
    return 0
}

main "$@"
exit $?
