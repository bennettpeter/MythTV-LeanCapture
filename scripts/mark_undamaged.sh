#!/bin/bash

# Mark recording as undamaged so as not to re-record
# Parameter 1 - Channel number
# Parameter 2 - date in UCT e.g. 2022-02-03
# Parameter 3 - time in UCT e.g. 14:19:25
#
# Current time in UCT
#  date -u '+%Y-%m-%d %H:%M:%S'
# Converting date/time to UCT :
#  date -u '+%Y-%m-%d %H:%M:%S' -d @$(date +%s -d "2022-02-03 09:19:25")

channum="$1"
time="$2 $3"

if [[ "$channum" == "" || "$2" == "" || "$3" == "" ]] ; then
    echo Mark recording as undamaged
    echo $0 "<Channel number> <error date> <error time>"
    echo Date and time in UCT
    echo Example:
    echo $0 710 2022-02-03 14:19:25
    exit 2
fi
. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

# Get DB password from config.xml
. $scriptpath/getconfig.sh

sql="SELECT chanid, starttime, videoprop, title
FROM recordedprogram
INNER JOIN channel using (chanid)
WHERE
manualid='0' and channum='$channum'
and starttime <= '$time'
and endtime > '$time';"

echo "$sql"

str=$(echo "$sql" | $mysqlcmd -B )

IFS=$'\t' read chanid starttime videoprop title more <<<"$str"

echo $chanid / $starttime / $videoprop / $title

if [[ "$more" != "" ]] ; then
    echo "ERROR: More than 1 record found"
    exit 2
elif [[ "$title" == "" ]] ; then
    echo "ERROR: No record found"
    exit 2
fi

if [[ "$videoprop" != *DAMAGED* ]] ; then
    echo "Recording was not marked damaged"
else
    newprop=$(echo "$videoprop" | sed "s/,DAMAGED//;s/DAMAGED,//")
    sql="UPDATE recordedprogram
    SET videoprop = '$newprop'
    WHERE chanid = '$chanid' and starttime = '$starttime' and manualid = '0';"
    echo "$sql"
    echo "$sql" | $mysqlcmd
fi

sql="UPDATE recorded
SET duplicate = 1
WHERE
chanid='$chanid'
and starttime <= '$time'
and endtime > '$time';"

echo "$sql"
echo "$sql" | $mysqlcmd

sql="UPDATE oldrecorded
SET duplicate = 1
WHERE
chanid='$chanid'
and starttime <= '$time'
and endtime > '$time';"

echo "$sql"
echo "$sql" | $mysqlcmd

mythutil --resched

localdate=$(date -d "$starttime UTC")
echo "Program $title on channel $channum at $localdate is now marked as NOT DAMAGED"
