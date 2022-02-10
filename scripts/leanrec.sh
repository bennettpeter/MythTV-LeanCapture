#!/bin/bash
# Record from Amazon Prime

title=

minutes=120
recname=leancap1
wait=1
season=
episode=
wait=0
ADB_ENDKEY=

while (( "$#" >= 1 )) ; do
    case $1 in
        --title|-t)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                title="$2"
                shift||rc=$?
            fi
            ;;
        --time)
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
        --season|-S)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                season="$2"
                shift||rc=$?
            fi
            ;;
        --episode|-E)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                episode="$2"
                shift||rc=$?
            fi
            ;;
        --wait)
            wait=1
            ;;
        *)
            echo "Invalid option $1"
            error=y
            ;;
    esac
    shift||rc=$?
done

if [[ "$error" == y || "$title" == "" || "$season" == "" \
      || "$episode" == ""  ]] ; then
    echo "*** $0 ***"
    echo "Generic Record"
    echo "Disable autoplay"
    echo "Title season and expisode are for naming the recording"
    echo "Start with appropriate show selected and ready."
    echo "After recording will not return to HOME unless there was an error."
    echo "Input parameters:"
    echo "--title|-t xxxx : Title"
    echo "--time nn : Maximum Number of minutes [default 120]"
    echo "--recname|-n xxxxxxxx : Recorder id (default leancap1)"
    echo "--season|-S nn : Season without leading zeroes"
    echo "--episode|-E nn : Episode without leading zeroes"
    echo "--wait : Pause immediately before playback, for testing"
    echo "    or to rewind in progress show to beginning."
    exit 2
fi

. /etc/opt/mythtv/leancapture.conf

if [[ -f $VID_RECDIR/STOP_RECORDINGS ]] ; then
    echo "Exiting because of file $VID_RECDIR/STOP_RECORDINGS"
    exit 3
fi

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

if (( ! wait )) ; then
    ADB_ENDKEY=HOME
fi
source $scriptpath/leanfuncs.sh
initialize
echo `$LOGDATE` "RECORD: Title $title, S${season}E${episode}"
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

adb connect $ANDROID_DEVICE
if ! adb devices | grep $ANDROID_DEVICE ; then
    echo `$LOGDATE` "ERROR: Unable to connect to $ANDROID_DEVICE"
    exit 2
fi

# Check season and episode
if ! waitforstring "\nSeason $season.*Episode $episode " "Season and Episode" ; then
    echo `$LOGDATE` "ERROR - Wrong Season & Episode Selected"
    exit 2
fi

if (( ${#season} == 1 )) ; then
    season=0$season
fi
if (( ${#episode} == 1 )) ; then
    episode=0$episode
fi
season_episode=S${season}E${episode}

recfilebase="$VID_RECDIR/$title/$season_episode"
recfile="$recfilebase.mkv"
xx=
while [[ -f "$recfile" ]] ; do
    let xx++
    recfile="${recfilebase}_$xx.mkv"
    echo `$LOGDATE` "Duplicate recording file, appending _$xx"
done

if (( wait )) ; then
    echo "Ready to start recording of $recfile"
    echo "Type Y to start, anything else to cancel"
    echo "This script will press DPAD_CENTER to start. Do not press it."
    read -e resp
    if [[ "$resp" != Y ]] ; then exit 2 ; fi
    # Kill vlc
    while pidof vlc ; do
        wmctrl -c vlc
        sleep 2
    done
    ADB_ENDKEY=HOME
fi

mkdir -p "$VID_RECDIR/$title"

echo `$LOGDATE` "Starting recording of $recfile"
# Start Recording

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
"$recfile" &

ffmpeg_pid=$!
starttime=`date +%s`
let maxduration=minutes*60
let maxendtime=starttime+maxduration
let minendtime=starttime+300
sleep 20
filesize=0
lowcount=0
while true ; do
    now=`date +%s`
    if (( now > maxendtime )) ; then
        echo `$LOGDATE` "Recording for too long, kill it"
        exit 2
    fi
    if ! ps -q $ffmpeg_pid >/dev/null ; then
        echo `$LOGDATE` "ffmpeg is gone, exit"
        exit 2
    fi
    capturepage adb
    if [[ "$pagename" != "" ]] || (( lowcount > 4 )) ; then
        kill $ffmpeg_pid
        sleep 2
        capturepage
        echo `$LOGDATE` "Recording $recfile ended."
        break
    fi
    sleep 60
    newsize=`stat -c %s "$recfile"`
    let diff=newsize-filesize
    filesize=$newsize
    echo `$LOGDATE` "size: $filesize  Incr: $diff"
    if (( diff < 5000000 )) ; then
        let lowcount++
        echo `$LOGDATE` "Less than 5 MB, lowcount=$lowcount"
    else
        lowcount=0
    fi
done
ADB_ENDKEY=
if (( now < minendtime )) ; then
    echo `$LOGDATE` "ERROR Recording is less than 5 minutes"
    exit 2
fi
echo `$LOGDATE` "Complete - Recorded"
