#!/bin/bash
# Record from Amazon Prime

title=

minutes=
recname=leancap1
wait=1
season=
episode=
wait=0
ADB_ENDKEY=
srch=
prekeys=
postkeys=
dosrch=1
playing=0

while (( "$#" >= 1 )) ; do
    case $1 in
        --title|-t)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                title="$2"
                shift||rc=$?
            fi
            ;;
        --time|-m)
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
        --srch)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                srch="$2"
                shift||rc=$?
            fi
            ;;
        --nosrch)
            dosrch=0
            ;;
        --playing)
            playing=1
            dosrch=0
            ;;
        --prekeys)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                prekeys="$2"
                shift||rc=$?
            fi
            ;;
        --postkeys)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                postkeys="$2"
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
      || "$episode" == "" || "$minutes" == "" ]] ; then
    echo "*** $0 ***"
    echo "Generic Record"
    echo "Disable autoplay"
    echo "Title season and expisode are for naming the recording"
    echo "Start with appropriate show selected and ready."
    echo "After recording will not return to HOME unless there was an error."
    echo "Input parameters:"
    echo "--title|-t xxxx : Title"
    echo "--time|-m nn : Estimated Number of minutes [required]"
    echo "    If show ends before 66% or after 133% of this it is an error"
    echo "--recname|-n xxxxxxxx : Recorder id (default leancap1)"
    echo "--season|-S nn : Season without leading zeroes"
    echo "--episode|-E nn : Episode without leading zeroes"
    echo "--srch string : Alternate search string for identifying correct page"
    echo "--nosrch : Do not check for correct page."
    echo "--playing : Do not send Enter key at start. Use when playback is already going"
    echo "    This also sets nosrch."
    echo "--prekeys string : Keystrokes to send before playback to get to correct page"
    echo "    This probably should not be used with playing option."
    echo "--postkeys string : Keystrokes to send after successful recording"
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

# Check resolution
CROP=" "
capturepage adb
rc=$?
if (( rc == 1 )) ; then exit $rc ; fi
# Send prekeys
if [[ "$prekeys" != "" ]] ; then
    $scriptpath/adb-sendkey.sh $prekeys
fi
# Check season and episode
if [[ "$srch" != "" ]] ; then
    str="$srch"
else
    str="\nSeason $season.*Episode $episode |\nSeason $season \($episode\)"
fi
if (( dosrch )) && ! waitforstring "$str" "Season and Episode" ; then
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
        sleep 1
    done
    ADB_ENDKEY=HOME
fi

mkdir -p "$VID_RECDIR/$title"

echo `$LOGDATE` "Starting recording of $recfile"
# Start Recording

if (( playing )) ; then
    # Wait for video device if it is in use for prior episode.
    for (( xx=0 ; xx < 10 ; xx++ )) ; do
        capturepage video
        if (( imagesize > 0 )) ; then break ; fi
        sleep 1
    done
    if (( imagesize == 0 )) ; then
        echo `$LOGDATE` "ERROR - Video device $VIDEO_IN is unavailable."
        exit 2
    fi
fi

if (( ! playing )) ; then
    $scriptpath/adb-sendkey.sh DPAD_CENTER
fi

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
-preset $X264_PRESET \
-crf $X264_CRF \
-c:a aac \
"$recfile" &

ffmpeg_pid=$!
starttime=`date +%s`
# Max duration is 50% more than specified duration.
let maxduration=minutes*60*150/100
# Min duration is 66% of specified duration.
let minduration=minutes*60*66/100
let maxendtime=starttime+maxduration
let firstminutes=starttime+120
let fiveminutes=starttime+300
let minendtime=starttime+minduration
echo "Minimum end time" $(date -d @$minendtime)
echo "Maximum end time" $(date -d @$maxendtime)
filesize=0
lowcount=0
# textoverlay indicates there is a text overlay on the video, which
# means text can pop up any time and therefore the value must be tested.
# If there in no text overlay you can assume the video is over as soon
# as you see text.
textoverlay=0
let minbytes=MINBYTES*2
while true ; do
    loopstart=`date +%s`
    if (( loopstart > maxendtime )) ; then
        echo `$LOGDATE` "ERROR: Recording for too long, kill it"
        exit 2
    fi
    if ! ps -q $ffmpeg_pid >/dev/null ; then
        echo `$LOGDATE` "ERROR: ffmpeg is gone, exit"
        exit 2
    fi
    for (( x=0; x<30; x++ )) ; do
        now=`date +%s`
        # Each outer loop should be approximately 1 minute
        if (( now - loopstart > 59 )) ; then
            break
        fi
        capturepage adb
        if (( ! textoverlay  && CAP_TYPE == 2 && now > firstminutes && now < fiveminutes )) ; then
            textoverlay=1
            echo `$LOGDATE` Blank Screen sets textoverlay flag.
        fi
        if [[ "$pagename" != "" ]] ; then
            # peacock select watch from start
            if [[ "$pagename" == "Would you like to watch from start or resume"* ]] ; then
                $scriptpath/adb-sendkey.sh DPAD_CENTER
                sleep 2
                continue
            fi
            if (( now < firstminutes )) ; then
                sleep 2
                continue
            fi
            if (( ! textoverlay )) ; then
                sleep 2
                echo `$LOGDATE` "Recording $recfile ended with text screen."
                break 2
            fi
            # peacock prompt: Cancel on last line
            # peacock prompt: "Up Next" on a whole line
            # tubi prompt: Starting in xx secondsS
            # peacock prompt - i TVMA
            if egrep -a '^Cancel$|^Up Next$|^i TVMA$|^Starting in [0-9]* seconds' $TEMPDIR/${recname}_capture_crop.txt ; then
                sleep 2
                echo `$LOGDATE` "Recording $recfile ended with Next Up prompt."
                break 2
            fi
            # Xfinity resume prompt and start over
            if [[ "$pagename" != "" ]] ; then
                if  grep "Resume" $TEMPDIR/${recname}_capture_crop.txt \
                    ||  grep "Start" $TEMPDIR/${recname}_capture_crop.txt ; then
                    echo `$LOGDATE` "Selecting Start Over from Resume Prompt"
                    $scriptpath/adb-sendkey.sh DOWN
                    $scriptpath/adb-sendkey.sh DPAD_CENTER
                fi
            fi
        fi
        sleep 2
    done
    if (( lowcount > 6 )) ; then
        echo `$LOGDATE` "ERROR: Recording seems to have stuck, kill it"
        exit 2
    fi
    newsize=`stat -c %s "$recfile"`
    let diff=newsize-filesize
    filesize=$newsize
    echo `$LOGDATE` "size: $filesize  Incr: $diff"
    if (( diff < minbytes )) ; then
        let lowcount++
        echo `$LOGDATE` "Less than minbytes, lowcount=$lowcount"
    else
        lowcount=0
    fi
done
if (( now < minendtime )) ; then
    echo `$LOGDATE` "ERROR Recording is less than minimum, kill it"
    exit 2
fi
ADB_ENDKEY="$postkeys"
echo `$LOGDATE` "Complete - Recorded"
