#!/bin/bash

# External Recorder New episode on same channel
# Parameter 1 - recorder name
# Paramater 2 - channel number, unused

recname=$1
channum=$2

MINTIME=300

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/leanfuncs.sh
initialize
getparms

echo `$LOGDATE` "New Episode on chennel $channum "

if locktuner ; then
    unlocktuner
    echo `$LOGDATE` "Encoder $recname is not locked, exiting"
    exit
fi

# Do not use gettunestatus here because that tries to lock and fails
# if it cannot

tunefile=$TEMPDIR/${recname}_tune.stat
source $tunefile

if [[ "$tunestatus" == tuned ]] ; then
    now=$(date +%s)
    let elapsed=now-tunetime
    if (( elapsed > MINTIME )) ; then
        # A button press to ensure the playback does not stop with
        # "Are you still there"
        adb connect $ANDROID_DEVICE
        sleep 0.5
        # Let Android know we are still here - this displays progress bar briefly
        $scriptpath/adb-sendkey.sh DPAD_CENTER
        echo "tunetime=$(date +%s)" >> $tunefile
        echo `$LOGDATE` "Prodded $recname"
    else
        echo `$LOGDATE` "Too soon to prod $recname"
    fi
else
    echo `$LOGDATE` "Encoder $recname is not tuned, exiting"
fi
exit 0
