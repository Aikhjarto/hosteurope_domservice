#!/bin/bash
# Script for automatically update a DNS-A entry for domains hosted by http://hosteurope.de
# The purpose of this script is to have a DNS update functionality similar to dyndns, no-ip, or afraid.org.
# It requires the credential as environmental variable
#export HE_CNUMBER="12345" 		# Hosteurope "Kundennmmer"
#export HE_PASSWORD="mypassword" 	# Hosteurope password (must be urlencoded)


HE_DOMAIN="wa2.eu"		# Domain name
HOST="addtest"		# Host Name
#NEW_IP="3.2.1.2" 	# Desired IP address (if not set, external IP will be used)
#export HE_CNUMBER="12345" 		# Hosteurope "Kundennmmer"
#export HE_PASSWORD="mypassword" 	# Hosteurope password (must be urlencoded)

# uncomment first line if you have curl and second line if you have wget
#FETCH_BIN="curl -s --url"
FETCH_BIN="wget -qO-"

# Regular expression for valid IPv4 adresses
REGEX_IS_IP="(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"

# file to temporary store data
TMP_FILE="/tmp/hosteurope_update_DNS_A.tmp"

# URL-start (use variable since it occurs so often
URL_START="https://kis.hosteurope.de/administration/domainservices/index.php?menu=2&submode=edit&mode=autodns&domain=$HE_DOMAIN&kdnummer=$HE_CNUMBER&passwd=$HE_PASSWORD"

# get list of all DNS entries (more information is stored on the webpage than it's visible). Purge unneeded stuff to save space (important on embedded devices)
$FETCH_BIN "$URL_START" | grep -e "$HOST.$HE_DOMAIN" -e "hidden" -e "record" | grep -v $HE_PASSWORD> $TMP_FILE

# fine line where information about $HOST starts
START_LINE=$(grep -n "$HOST.$HE_DOMAIN" $TMP_FILE | cut -f1 -d:)
if [ -z $START_LINE ]; then
	logger -s "DNS Update Hosteurope: can't find $HOST.$HE_DOMAIN as vaild entry in https://kis.hosteurope.de/administration/domainservices/index.php?menu=2&mode=autodns&submode=edit&domain=$HE_DOMAIN"
	exit 1
fi

# from $START_LINE search in the next 10 lines for a hostid and eliminate clutter like "value=". The limit of 10 lines is necessary to avoid fetching hostid of wrong host.
HOSTID=$(tail -n +$START_LINE $TMP_FILE | head -n 10 | grep hostid | awk '{ print $4 }' | sed -e 's/value="//' -e 's/"//')
if [ -z $HOSTID ]; then
	logger -s "DNS Update Hosteurope: can't fetch HOSTID for host $HOST.$HE_DOMAIN"
	exit 1
fi

# same for getting old IP
OLD_IP=$(tail -n +$START_LINE $TMP_FILE | head -n 10 | grep -e "select name=\"record" | awk '{ print $19 }' | sed -e 's/value="//' -e 's/"><br//' | head -n 1 | grep -E "$REGEX_IS_IP" )
if [ -z $OLD_IP ]; then
	logger -s "DNS Update Hosteurope: can't fetch OLD_IP for host $HOST.$HE_DOMAIN"
	exit 1
fi

# get IP if not already set by $NEW_IP
if [ -z $NEW_IP ]; then
	NEW_IP=$($FETCH_BIN "http://ifconfig.me/ip" | grep -E "$REGEX_IS_IP" )
	if [ -z $NEW_IP ]; then
		logger -s "DNS Update Hosteurope: can't fetch CURRENT_IP from http://ifconfig.me/ip"
		exit 1
	fi
fi

# update only if something had changed (hosteurope gets annoyed if you spam updates too frequently)
if [ $OLD_IP != $NEW_IP ]; then
	$FETCH_BIN "$URL_START&record=0&pointer=$NEW_IP&submit=Update&truemode=host&hostid=$HOSTID" > /dev/null
fi

# logout
$FETCH_BIN "https://kis.hosteurope.de/?kdnummer=$HE_CNUMBER&passwd=$HE_PASSWORD&logout=1"

# delete temp file
rm $TMP_FILE