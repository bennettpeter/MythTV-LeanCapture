#!/bin/bash
# Record from fire stick

responses=0
minutes=360
recname=leancap1
endkey=HOME
waitforstart=1

while (( "$#" >= 1 )) ; do
    case $1 in
        --responses|-r)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                responses="$2"
                shift||rc=$?
            fi
            ;;
        --time|-t)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                minutes="$2"
                shift||rc=$?
            fi
            ;;
        --recname|-n)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                recname="$2"
                shift||rc=$?
            fi
            ;;
        --nohome)
            endkey=
            ;;
        --nowait)
            waitforstart=0
            ;;
        *)
            echo "Invalid option $1"
            error=y
            ;;
    esac
    shift||rc=$?
done

if [[ "$error" == y ]] ; then
    echo "*** $0 ***"
    echo "Input parameters:"
    echo "--responses|-r nn : Number of responses (default 0)"
    echo "--time|-t nn : Maximum Number of minutes [default 360]"
    echo "--recname|-n xxxxxxxx : Recorder id (default leancap1)"
    echo "--nohome : Do not return to HOME at exit"
    echo "--nowait : Start immediately without prompt"
    exit 2
fi

. /etc/opt/mythtv/leancapture.conf

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/leanfuncs.sh

let responses=responses
let minutes=minutes
# Default to 360 minutes - 6 hours
if (( $minutes == 0 )) ; then
    echo "Invalid time value $minutes"
    exit 2
fi
echo
let seconds=minutes*60
echo "Record for $minutes minutes and respond $responses times."
if (( responses > 10 )) ; then
    echo "ERROR Invalid response count $responses, maximum is 10"
    exit 2
fi
echo "This script will press DPAD_CENTER to start. Do not press it."
if (( waitforstart )) ; then
    echo "Type Y to start"
    read -e resp
    if [[ "$resp" != Y ]] ; then exit 2 ; fi
fi

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
while pidof vlc ; do
    wmctrl -c vlc
    sleep 2
done

recfile=`$LOGDATE`
echo `$LOGDATE` "Starting recording of ${recfile}"
ADB_ENDKEY="$endkey"
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
-crf $X264_CRF \
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
            echo `$LOGDATE` "Playback paused too long"
            break 2
        fi
        newsize=`stat -c %s $VID_RECDIR/${recfile}.mkv`
        let diff=newsize-filesize
        filesize=$newsize
        echo `$LOGDATE` "size: $filesize  Incr: $diff"
        if (( diff < 4000000 )) ; then
            let lowcount=lowcount+1
            echo `$LOGDATE` "Less than 4 MB, lowcount=$lowcount"
            CROP=" "
            capturepage adb
            if (( imagesize > 0 )) ; then
                # Hulu default message after 4-5 hours, or after end of series
                if egrep "YES, CONTINUE WATCHING|More to Watch|Are you still watching" \
                        $DATADIR/${recname}_capture_crop.txt ; then
                    echo `$LOGDATE` "Playback ended with prompt"
                    if (( xx < responses )) ; then break ; fi
                    break 2
                elif egrep "An error has occurred during video playback" \
                        $DATADIR/${recname}_capture_crop.txt ; then
                    echo `$LOGDATE` "Sending enter to get past error message"
                    $scriptpath/adb-sendkey.sh DPAD_CENTER
                    sleep 30
                    break
                fi
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
