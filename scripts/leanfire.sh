#!/bin/bash
# Record from fire stick

responses="$1"
minutes="$2"
recname="$3"
if [[ "$recname" == "" ]] ; then
    recname=leancap1
fi

echo "*** $0 ***"
echo "Input parameters:"
echo "Number of responses (default 0)"
echo "Maximum Number of minutes [default 360*(responses+1)]"
echo "Recorder id (default leancap1)"

. /etc/opt/mythtv/leancapture.conf

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/leanfuncs.sh

let responses=responses
let minutes=minutes
# Default to 360 minutes - 6 hours
if (( $minutes == 0 )) ; then
    let minutes=360*\(responses+1\)
fi
echo
let seconds=minutes*60
echo "Record for $minutes minutes and respond $responses times."
if (( responses > 10 )) ; then
    echo "ERROR Invalid response count $responses"
    exit 2
fi
echo "This script will press DPAD_CENTER to start. Do not press it."
echo "Type Y to start"
read -e resp
if [[ "$resp" != Y ]] ; then exit 2 ; fi

initialize
if ! getparms PRIMARY ; then
    exit 2
fi
ffmpeg_pid=

# Tuner kept locked through entire recording
if ! locktuner ; then
    echo `$LOGDATE` "ERROR Encoder $recname is locked."
    exit 2
fi
gettunestatus

if [[ "$tunestatus" != idle ]] ; then
    echo `$LOGDATE` "ERROR: Tuner in use. Status $tunestatus"
    exit 2
fi

echo `$LOGDATE` "Record for $minutes minutes and respond $responses times."

adb connect $ANDROID_DEVICE
if ! adb devices | grep $ANDROID_DEVICE ; then
    echo `$LOGDATE` "ERROR: Unable to connect to $ANDROID_DEVICE"
    exit 2
fi

CROP=" "
capturepage adb
rc=$?
if (( rc == 1 )) ; then exit $rc ; fi

# Kill vlc
wmctrl -c vlc
wmctrl -c obs
sleep 2

recfile=`$LOGDATE`
echo `$LOGDATE` "Starting recording of ${recfile}"
ADB_ENDKEY=HOME
$scriptpath/adb-sendkey.sh DPAD_CENTER

ffmpeg -hide_banner -loglevel error \
-f v4l2 \
-thread_queue_size 256 \
-input_format $INPUT_FORMAT \
-framerate $FRAMERATE \
-video_size $RESOLUTION \
-use_wallclock_as_timestamps 1 \
-i $VIDEO_IN \
-f alsa \
-ac 2 \
-ar 48000 \
-thread_queue_size 1024 \
-itsoffset $AUDIO_OFFSET \
-i $AUDIO_IN \
-c:v libx264 \
-vf format=yuv420p \
-preset faster \
-crf 23 \
-c:a aac \
$VID_RECDIR/${recfile}.mkv &

# Removed
# -f pulse \
# -i "alsa_input.usb-MACROSILICON_2109-02.analog-stereo" \

ffmpeg_pid=$!
starttime=`date +%s`
let endtime=starttime+seconds
filesize=0
let loops=responses+1
for (( xx = 0 ; xx < loops ; xx++ )) ; do
    lowcount=0
    while true ; do
        sleep 60
        now=`date +%s`
        if (( now > endtime )) ; then
            echo `$LOGDATE` "Time Limit reached"
            break 2
        fi
        if ! ps -q $ffmpeg_pid >/dev/null ; then
            echo `$LOGDATE` "ffmpeg terminated"
            break 2
        fi
        if (( lowcount > 3 )) ; then
            echo `$LOGDATE` "Playback paused"
            if (( xx < responses )) ; then break ; fi
            break 2
        fi
        newsize=`stat -c %s $VID_RECDIR/${recfile}.mkv`
        let diff=newsize-filesize
        filesize=$newsize
        echo `$LOGDATE` "size: $filesize  Incr: $diff" >> $VID_RECDIR/${recfile}_size.log
        if (( diff < 4000000 )) ; then
            let lowcount=lowcount+1
            echo "*** Less than 4 MB *** lowcount=$lowcount" >> $VID_RECDIR/${recfile}_size.log
            CROP=" "
            capturepage adb
            if (( imagesize > 0 )) ; then
                echo `$LOGDATE` "Playback maybe paused, count $lowcount"
            fi
        else
            lowcount=0
        fi
    done
    sleep 1
    CROP=" "
    capturepage adb
    echo `$LOGDATE` "Sending enter to start next episode"
    sleep 1
    $scriptpath/adb-sendkey.sh DPAD_CENTER
    sleep 1
done
echo `$LOGDATE` "Playback finished"
