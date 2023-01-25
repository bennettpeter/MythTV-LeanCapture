#!/bin/bash
# Record from Amazon Prime

title=

minutes=
recname=leancap1
season=
episode=
wait=0
ADB_ENDKEY=
srch=
prekeys=
postkeys=
dosrch=0
playing=0
stopafter=
chapter=0
movie=0
# textoverlay indicates there is a text overlay on the video, which
# means text can pop up any time and therefore the value must be checked.
# If there in no text overlay you can assume the video is over as soon
# as you see text.
textoverlay=0


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
        --stopafter|-s)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                stopafter="$2"
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
        --movie|-M)
            movie=1
            ;;
        --srch)
            if [[ "$2" == "" || "$2" == -* ]] ; then
                # This indicates search with default string
                srch=
                dosrch=1
            else
                srch="$2"
                dosrch=1
                shift||rc=$?
            fi
            ;;
        --nosrch)
            dosrch=0
            srch=
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
        --chapter)
            chapter=1
            ;;
        --textoverlay)
            textoverlay=1
            ;;
        *)
            echo "Invalid option $1"
            error=y
            ;;
    esac
    shift||rc=$?
done

if [[ "$error" == y || "$title" == "" \
      || ( ( "$season" == "" || "$episode" == "" ) && "$movie" == 0 ) \
      || "$minutes" == "" ]] ; then
    echo "*** $0 ***"
    echo "Generic Record"
    echo "Disable autoplay"
    echo "Title season and episode are for naming the recording"
    echo "Start with appropriate show selected and ready."
    echo "After recording will not return to HOME unless there was an error."
    echo "title, time and either movie or season and episode are required"
    echo "Input parameters:"
    echo "--title|-t xxxx : Title"
    echo "--time|-m nn : Estimated Number of minutes"
    echo "    If show ends before 66% or after 133% of this it is an error"
    echo "--stopafter|-s nn : Stop after a number of minutes "
    echo "    Stop recording without error after this number of minutes"
    echo "    Should be used with postkeys to also stop the playback."
    echo "--recname|-n xxxxxxxx : Recorder id (default leancap1)"
    echo "--season|-S nn : Season without leading zeroes"
    echo "--episode|-E nn : Episode without leading zeroes"
    echo "--movie|-M : Recording a movie"
    echo "--srch : With no value srch will search using default string"
    echo "--srch string : Alternate search string for identifying correct page"
    echo "--nosrch : Do not check for correct page. This is the default so can be omitted."
    echo "--playing : Do not send Enter key at start. Use when playback is already going"
    echo "    This also sets nosrch."
    echo "--prekeys string : Keystrokes to send before playback to get to correct page"
    echo "    This probably should not be used with playing option."
    echo "--postkeys string : Keystrokes to send after successful recording"
    echo "--wait : Pause immediately before playback, for testing"
    echo "    or to rewind in progress show to beginning."
    echo "--chapter : Record only one chapter"
    echo "    Only for services with text overlay"
    echo "--textoverlay : Service uses textoverlay"
    echo "    For service that has text ads and more than 3 minutes of ads at the start."
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

source $scriptpath/leanfuncs.sh
initialize

if (( ! wait )) ; then
    ADB_ENDKEY=HOME
fi

if (( movie )) ; then
    directory=Movies
    file="$title"
else
    directory="$title"
    if (( ${#season} == 1 )) ; then
        season=0$season
    fi
    if (( ${#episode} == 1 )) ; then
        episode=0$episode
    fi
    file=S${season}E${episode}
fi
echo `$LOGDATE` "RECORD: $directory, $file"
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

recfilebase="$VID_RECDIR/$directory/$file"
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

mkdir -p "$VID_RECDIR/$directory"

echo `$LOGDATE` "Starting recording of $recfile"
# Start Recording

if (( playing )) ; then
    # Wait for video device if it is in use for prior recording.
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
    sleep 2
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
# firstminutes is the max length of ads at the beginning
let firstminutes=starttime+180
let blankminutes=starttime+360
let minendtime=starttime+minduration
if (( chapter )) ; then
    minendtime=0
else
    echo "Minimum end time" $(date -d @$minendtime)
fi
echo "Maximum end time" $(date -d @$maxendtime)
stoptime=0
if (( stopafter > 0 )) ; then
    let stoptime=starttime+stopafter*60
    echo "Stop time" $(date -d @$stoptime)
fi
filesize=0
lowcount=0
let minbytes=MINBYTES*2
duptext=0
while true ; do
    loopstart=`date +%s`
    if (( loopstart > maxendtime )) ; then
        echo `$LOGDATE` "ERROR: Recording for too long, kill it"
        exit 2
    fi
    if (( stoptime > 0 && loopstart > stoptime )) ; then
        sleep 2
        echo `$LOGDATE` "Recording $recfile ended for Stop Time reached."
        break
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
        # CAP_TYPE 2 is "blank text screen"
        if (( ! textoverlay  && CAP_TYPE == 2 && now > firstminutes && now < blankminutes )) ; then
            textoverlay=1
            echo `$LOGDATE` Blank Screen sets textoverlay flag.
        fi
        # CAP_TYPE 1 is "same text as before"
        if (( CAP_TYPE == 1 )) ; then
            let duptext++
        else
            duptext=0
        fi
        if [[ "$pagename" != "" ]] ; then
            # peacock "Are you still watching?" prompt
            if grep "Are you still watching" $TEMPDIR/${recname}_capture_crop.txt ; then
                echo `$LOGDATE` "Responding to 'Are you still watching?' Prompt"
                $scriptpath/adb-sendkey.sh DPAD_CENTER
                sleep 2
            fi

            # peacock select watch from start or resume
            # default is resume, use right center to resume
            #~ if [[ "$pagename" == "Would you like to watch from start or resume"* ]] ; then
                #~ $scriptpath/adb-sendkey.sh RIGHT DPAD_CENTER
                #~ sleep 2
                #~ continue
            #~ fi

            if (( now < firstminutes )) ; then
                sleep 2
                continue
            fi
            if (( ! textoverlay )) ; then
                # Xfinity resume prompt and start over
                if  grep "Resume" $TEMPDIR/${recname}_capture_crop.txt \
                    ||  grep "Start" $TEMPDIR/${recname}_capture_crop.txt ; then
                    echo `$LOGDATE` "Selecting Start Over from Resume Prompt"
                    $scriptpath/adb-sendkey.sh DOWN
                    $scriptpath/adb-sendkey.sh DPAD_CENTER
                    continue
                fi
                sleep 2
                echo `$LOGDATE` "Recording $recfile ended with text screen."
                break 2
            fi
            if (( chapter )) ; then
                sleep 2
                echo `$LOGDATE` "Recording $recfile ended at chapter end."
                break 2
            fi

            # If stopped on a text page for 5 iterations (10-15 sec), end recording
            if (( duptext > 5 )) ; then
                echo `$LOGDATE` "Recording $recfile ended on static text 5 times."
                break 2
            fi
            # peacock prompt: Cancel on last line
            # peacock prompt: "Up Next" on a whole line
            # tubi prompt: Starting in xx secondsS
            # peacock prompt - i TVMA or i TV-14
            # Hulu no ads prompt "Episodes Inside the Episodes"
            # HBOMAX: "AUTOPLAY OFF" or "NEXT EPISODE " or "Seasons [0-9]"
            if egrep -a '^Cancel$|^Up Next$|^i *TV.{2,3}$|^Starting in [0-9]* seconds|Episodes|AUTOPLAY OFF|NEXT EPISODE |Seasons [0-9]' $TEMPDIR/${recname}_capture_crop.txt ; then
                sleep 2
                echo `$LOGDATE` "Recording $recfile ended with text prompt."
                break 2
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

if [[ -f $VID_RECDIR/STOP_RECORDINGS ]] ; then
    echo "Exiting because of file $VID_RECDIR/STOP_RECORDINGS"
    ADB_ENDKEY=HOME
    exit 3
fi

ADB_ENDKEY="$postkeys"
echo `$LOGDATE` "Complete - Recorded"
