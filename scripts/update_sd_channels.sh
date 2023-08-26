#!/bin/bash

# Update sqlite SD database with available channels
# This uses the list created in leancap_chanlist.sh

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

if [[ ! -w "$SDSQLITEDB" ]] ; then
    echo "Invalid sqlite db file: $SDSQLITEDB"
    exit 2
fi

echo $scriptname updating xmltv channels

chanlistfile=$DATADIR/"$NAVTYPE".txt
sqlfile=$DATADIR/"$NAVTYPE".sql
true > "$sqlfile"

echo "update channels set selected = 0;" >> "$sqlfile"

awk '{ print "update channels set selected = 1 where channum = " $1 ";" }' < "$chanlistfile" >> "$sqlfile"

sqlite3 "$SDSQLITEDB" < "$sqlfile"
