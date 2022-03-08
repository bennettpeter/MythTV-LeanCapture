#!/bin/bash

# External Recorder Finished Recording
# Parameter 1 - recorder name

recname=$1

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/leanfuncs.sh

initialize
getparms
if ! locktuner 120 ; then
    echo `$LOGDATE` "Unable to lock tuner $recname - aborting"
    exit 2
fi
gettunestatus
# Set this to kill recording in case it has not actually finished
ffmpeg_pid=$tune_ffmpeg_pid
if [[ "$tunestatus" == tuned  ]] ; then
    echo `$LOGDATE` "Ending playback"
    adb connect $ANDROID_DEVICE
    $scriptpath/adb-sendkey.sh BACK
    # Clear tunefile
    echo "tunetime=$(date +%s)" > $tunefile
else
    echo `$LOGDATE` "Playback ended"
fi
# Mark failed recording if applicable
(
    sleep 10
    while [[ -f $DATADIR/${recname}_damage.txt \
         || -f $DATADIR/${recname}_damage.wrk ]] ; do
         if [[ ! -f $DATADIR/${recname}_damage.wrk ]] ; then
            mv -f $DATADIR/${recname}_damage.txt $DATADIR/${recname}_damage.wrk
        fi
        while read channum date time ; do
            $scriptpath/mark_damaged.sh $channum $date $time
        done < $DATADIR/${recname}_damage.wrk
        rm -f $DATADIR/${recname}_damage.wrk
    done
) &
