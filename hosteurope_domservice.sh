#!/bin/bash
#
# hosteurope_domservice.sh allows to manipulate DNS entries for domains registered
# at hosteurope.de. It employes the api from kis.hosteurope.de.
# 
# This script assumes the customer number and password of your Hosteurope account
# stored in the following environment variables:
# export HE_USERNAME=myusername		# Hosteurope username
# export HE_PASSWORD=mypassword		# Hosteurope password (must be urlencoded)
#
# Usage: hosteurope_domservice.sh domain command record type name value
# * domain: domain name like example.com
# * command: add, update, delete, or get
# * record type: supported types of resource records are A, AAAA, TXT, or CNAME
# * name: the name of the resource record
# * value: value to set
#
# Requirements:
# * curl or wget
# * logger
# * some standard tools like grep, head, tail, awk, sed, cut
#
# No output is written to stdout, so this script is suitable for using with cron.

# Make the script more robust
set -e
set -u

# set defaults
DOMAIN=${1}
RECORDTYPE=0
NAME=testhost
VALUE=127.0.0.1
DEBUG=""
LOGGER_OPTS="-t hosteurope_domservice.sh -s"
URL_PROC=""

if [ -z "$HE_USERNAME" ]; then
	echo "HE_USERNAME is unset or empty"
	exit
fi

if [ -z "$HE_PASSWORD" ]; then
	echo "HE_PASSWORD is unset or empty"
	exit
fi

# file to temporary store the data for all DNS entries
TMP_FILE="/tmp/hosteurope_DNS_dump.tmp"

# file to store result
RES_FILE="/tmp/hosteurope_DNS_rec.html"

# get HOSTID by $NAME and $DOMAIN
get_hostid() {
	# fine line where information about $NAME starts
	get_start_line

	# from $START_LINE search in the next 10 lines for a hostid and eliminate clutter like "value=". The limit of 10 lines is necessary to avoid fetching hostid of wrong host.
	HOSTID=$(tail -n +$START_LINE $TMP_FILE | head -n 8 | grep hostid | awk '{ print $4 }' | sed -e 's/value="//' -e 's/"//' | head -n 1)
	if [ -z $HOSTID ]; then
		logger $LOGGER_OPTS "ERROR: Can't fetch HOSTID for entry type $RECORDTYPE $NAME.$DOMAIN"
		exit 1
	fi

	if [ ! -z $DEBUG ]; then
		logger $LOGGER_OPTS "DEBUG: HOSTID=$HOSTID"
	fi
}

# get old value a an entry with $NAME
get_old_value() {
	get_start_line
	# same for getting old IP
	OLD_VAL=$(tail -n +$START_LINE $TMP_FILE | head -n 8 | grep -e "select name=\"record" | awk '{ print $19 }' | sed -e 's/value="//' -e 's/"><br//' | head -n 1 )
	# grep -E "$REGEX_IS_IP" )
	if [ -z $OLD_VAL ]; then
		logger $LOGGER_OPTS "ERROR: Can't fetch entry for type $RECORDTYPE $NAME.$DOMAIN"
		exit 1
	fi
	if [ ! -z $DEBUG ]; then
		logger $LOGGER_OPTS "DEBUG: OLD_VAL=$OLD_VAL"
	fi
}

# get the line where the entry with $NAME is found in the cached file
get_start_line() {
	# fine line where information about $NAME starts
	START_LINES=$(grep -n ">$NAME.$DOMAIN<" ${TMP_FILE} | cut -f1 -d:)

	# multiple entries with same name but different record types are possible
	array=(${START_LINES// / })
	for i in "${!array[@]}"
	do
		if [ ! -z $DEBUG ]; then
			logger $LOGGER_OPTS "DEBUG: $i=>${array[i]}"
		fi
		# next line (+1) will contain a string with all possible record types prepended with the string "selected". Thus grab the record type directly in front of "selected".
		RECORDTYPE_QUERY=$(cat ${TMP_FILE} | head -$((${array[i]}+1)) | tail -1 | tr '>' '\n' | grep selected | sed -e 's/<option value="//' -e 's/"  selected="selected"//')
		if [ ! -z $DEBUG ]; then
			logger $LOGGER_OPTS "DEBUG: $RECORDTYPE_QUERY ${RECORDTYPE}"
		fi
		if [ ${RECORDTYPE_QUERY} -eq ${RECORDTYPE} ]; then
			START_LINE=${array[i]}
		fi
	done
	
	set +u
	if [ -z $START_LINE ]; then
		logger $LOGGER_OPTS "ERROR: Can't find $NAME.$DOMAIN as valid entry in https://kis.hosteurope.de/administration/domainservices/index.php?menu=2&mode=autodns&submode=edit&domain=$DOMAIN"
		logger $LOGGER_OPTS "ERROR: Maybe entry $NAME.$DOMAIN does not exist or credentials are wrong"
		exit 1
	fi
	set -u
	
	if [ ! -z $DEBUG ]; then
		logger $LOGGER_OPTS "DEBUG: START_LINE=$START_LINE"
	fi
}


# uncomment first line if you have curl and second line if you have wget
#FETCH_BIN="curl -s --url"
FETCH_BIN="wget -qO-"

# start URL
URL_START="https://kis.hosteurope.de/administration/domainservices/index.php?kdnummer=$HE_USERNAME&passwd=$HE_PASSWORD&menu=2&submode=edit&mode=autodns&domain=$DOMAIN"

# get list of all DNS entries (more information is stored on the webpage than it's visible). 
# Purge unneeded stuff to save space (important on embedded devices)
# Purge password to avoid having it lying around in clear text.
[[ -e $TMP_FILE ]] && rm $TMP_FILE
$FETCH_BIN "${URL_START}" | grep -e "$DOMAIN" -e "hidden" -e "record" | grep -v $HE_PASSWORD> $TMP_FILE
if [ ! -e $TMP_FILE ]; then
	logger $LOGGER_OPTS "ERROR: Can't fetch list of entries"
fi

# get record type
case ${3} in
	"TXT")
		RECORDTYPE=11
		;;
	"A")
		RECORDTYPE=0
		;;
	"AAAA")
		RECORDTYPE=28
		;;
	"CNAME")
		RECORDTYPE=10
		;;
	*)
		logger $LOGGER_OPTS "ERROR: unknown record type ${3}"
		exit 1
		;;
esac

# execute a certain command
case ${2} in
	"add")
		NAME=${4}
		VALUE=${5}
		URL_PROC="&hostadd=$NAME&record=$RECORDTYPE&pointeradd=$VALUE&truemode=host&action=add&submit=Neu+anlegen"
		;;
		
	"update")
		NAME=${4}
		VALUE=${5}
		
		get_hostid
		get_old_value
		
		if [ $OLD_VAL != $VALUE ]; then
			URL_PROC="&record=$RECORDTYPE&pointer=$VALUE&submit=Update&truemode=host&hostid=$HOSTID"
		fi
		;;
	"delete")
		NAME=${4}

		get_hostid

		URL_PROC="&record=$RECORDTYPE&pointer=$VALUE&submit=L%F6schen&truemode=host&hostid=$HOSTID&nachfrage=1"
		;;
	"get")
		NAME=${4}

		get_old_value

		echo $OLD_VAL
		;;
	*)
		logger $LOGGER_OPTS "ERROR: unknown command ${2}"
		exit 1
		;;
esac

# perform the command
if [ ! -z ${URL_PROC} ]; then
	# strip clear text username and password to prevent it from entering the logs
	PURGED_COMMAND=$(echo "${URL_START}${URL_PROC}" | sed -e "s/$HE_USERNAME/HE_USERNAME/" -e "s/$HE_PASSWORD/HE_PASSWORD/")
	
	if [ ! -z ${DEBUG} ]; then
		logger $LOGGER_OPTS "DEBUG: call to ${PURGED_COMMAND}"
	fi
	
	# delete old result file if there was one (to detect if one was written)
	[[ -e ${RES_FILE} ]] && rm ${RES_FILE}
	
	# perform requested action
	$FETCH_BIN "${URL_START}${URL_PROC}" | grep -v $HE_PASSWORD > ${RES_FILE}
	if [ "$?" -ne 0 ]; then
		logger $LOGGER_OPTS "ERROR: Can't execute $FETCH_BIN ${PURGED_COMMAND}"
	fi

	# check if we got a result
	if [ ! -e ${RES_FILE} ]; then
		logger $LOGGER_OPTS "ERROR: $FETCH_BIN ${PURGED_COMMAND} did not produce a result"
	fi

	# display an error if any
	grep -A 10 -B 10 FEHLER ${RES_FILE}
	
fi

# delete temporary files when not in debug mode
if [ -z ${DEBUG} ]; then
	rm "${TMP_FILE}"
	rm "${RES_FILE}"
fi
