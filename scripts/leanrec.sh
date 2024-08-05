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
extension=mkv
capture=adb
# textoverlay indicates there is a text overlay on the video, which
# means text can pop up any time and therefore the value must be checked.
# If there in no text overlay you can assume the video is over as soon
# as you see text.
textoverlay=0
# Number of seconds of credits allowed at end of show
credits=450
# fffirst means ffmpeg must be running before you start playback
fffirst=0
# peacock prompt: CANCEL on last line
# peacock prompt: "Up Next" on a whole line
# tubi prompt: Starting in xxs or Starting inxs
# peacock prompt - i TVMA or i TV-14
# Hulu BACK TO BROWSE
# MAX: "AUTOPLAY OFF" or "Next Episode " or "Seasons [0-9]"
endtext='^CANCEL$|^Up Next$|^i *TV.{2,3}$|^Starting in *[0-9]|BACK TO BROWSE|AUTOPLAY OFF|Next Episode |Seasons [0-9]'

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
        --extension|-e)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                extension="$2"
                shift||rc=$?
            fi
            ;;
        --capture)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                capture="$2"
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
        --credits)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                credits="$2"
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
        --hulu)
            textoverlay=1
            endtext='BACK TO BROWSE|SEASON [0-9]+$'
            ;;
        --tubi)
            textoverlay=1
            endtext='Starting in *[0-9]+s$'
            ;;
        --fffirst)
            fffirst=1
            ;;
        *)
            echo "Invalid option $1"
            error=y
            ;;
    esac
    shift||rc=$?
done

case "$capture" in
    adb)
        ;;
    file)
        if [[ "$extension" != ts ]] ; then
            echo "ERROR file capture requres ts extension"
            error=y
        fi
        ;;
    *)
        echo "ERROR Invalid capture value $capture"
        error=y
        ;;
esac

if (( credits < 90 )) ; then
    echo "ERROR credits minimum value is 90"
    error=y
fi

maxlowcount=credits/30
let xtra=credits%30
if (( xtra > 0 ))  ; then
    let maxlowcount++
fi

if [[ "$stopafter" != "" ]] ; then
    minutes="$stopafter"
fi

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
    echo "    If show ends before 90% or after 150% of this it is an error"
    echo "    Not used if stopafter is used."
    echo "--stopafter|-s nn : Stop after a fixed number of minutes "
    echo "    Stop recording without error after this number of minutes"
    echo "    Should be used with postkeys to also stop the playback."
    echo "    If recording ends before this it is an error."
    echo "--recname|-n xxxxxxxx : Recorder id (default leancap1)"
    echo "--season|-S nn : Season without leading zeroes"
    echo "--episode|-E nn : Episode without leading zeroes"
    echo "--extension|-e xxx : File extension, determines type. Default mkv."
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
    echo "--capture adb|file : Method of monitoring messages. file requires extension ts"
    echo "--hulu : Set up for recording Hulu."
    echo "    Sets textoverlay and customized ennd text"
    echo "--tubi : Set up for recording Tubi."
    echo "    Tubi has Autoplay on, needs --playing on next leanrec, --postkeys HOME on last."
    echo "--credits nnn : Number of seconds of credits at the end of show."
    echo "    After this number, recording stops. Default 450, minimum 90"
    echo "--fffirst : Starte ffmpeg first before starting playback. This is needed"
    echo "    For Apple TV+ and any others that are able to detect that the data is"
    echo "    not being processed and then stops playback."
    exit 2
fi

. /etc/opt/mythtv/leancapture.conf

if [[ -f $VID_RECDIR/STOP_RECORDINGS ]] ; then
    echo "Exiting because of file $VID_RECDIR/STOP_RECORDINGS"
    ADB_ENDKEY=HOME
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
if [[ "$fffirst" == 0 && "$prekeys" != "" ]] ; then
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
RECFILE="$recfilebase.$extension"
xx=
while [[ -f "$RECFILE" ]] ; do
    let xx++
    RECFILE="${recfilebase}_$xx.$extension"
    echo `$LOGDATE` "Duplicate recording file, appending _$xx"
done

if (( wait )) ; then
    echo "Ready to start recording of $RECFILE"
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

echo `$LOGDATE` "Starting recording of $RECFILE"
# Start Recording

# Wait for video device if it is in use for prior recording.
for (( xx=0 ; xx < 30 ; xx++ )) ; do
    capturepage video
    if (( imagesize > 0 )) ; then break ; fi
    echo "Waiting for video device"
    sleep 1
done
if (( imagesize == 0 )) ; then
    echo `$LOGDATE` "ERROR - Video device $VIDEO_IN is unavailable."
    exit 2
fi

if (( ! playing )) ; then
    sleep 2
    if (( ! fffirst )) ; then
        $scriptpath/adb-sendkey.sh DPAD_CENTER
    fi
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
"$RECFILE" &

# This captures an image every 2 seconds but the audio cuts in and out
# if I use it.
#~ -vf fps=1/2 -an -update "$framefile" &

ffmpeg_pid=$!
starttime=`date +%s`
if (( ! playing )) ; then
    sleep 1
    if (( fffirst )) ; then
        $scriptpath/adb-sendkey.sh $prekeys DPAD_CENTER
    fi
fi

# Max duration is 50% more than specified duration.
let maxduration=minutes*60*150/100
# Min duration is 90% of specified duration.
let minduration=minutes*60*90/100
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
duptext=0
if [[ "$capture" == file ]] ; then
    textoverlay=1
fi
while true ; do
    loopstart=`date +%s`
    if (( loopstart > maxendtime )) ; then
        echo `$LOGDATE` "ERROR: Recording for too long, kill it"
        exit 2
    fi
    if (( stoptime > 0 && loopstart > stoptime )) ; then
        sleep 2
        echo `$LOGDATE` "Recording $RECFILE ended for Stop Time reached."
        break
    fi
    if ! ps -q $ffmpeg_pid >/dev/null ; then
        echo `$LOGDATE` "ERROR: ffmpeg is gone, exit"
        exit 2
    fi
    for (( x=0; x<30; x++ )) ; do
        now=`date +%s`
        # Each outer loop should be approximately 30 seconds
        if (( now - loopstart > 29 )) ; then
            break
        fi
        capturepage $capture
        # CAP_TYPE 2 is "blank text screen"
        if (( ! textoverlay  && CAP_TYPE == 2 && now > firstminutes && now < blankminutes )) ; then
            textoverlay=1
            echo `$LOGDATE` Blank Screen sets textoverlay flag.
        fi
        # CAP_TYPE 1 is "same text as before"
        if (( CAP_TYPE == 1 )) ; then
            # tubi message
            if egrep -a 'Your video will resume after the break' $TEMPDIR/${recname}_capture_crop.txt ; then
                duptext=0
            # Hulu just displays "Ad" during an ad
            elif [[ $(cat $TEMPDIR/${recname}_capture_crop.txt) == Ad ]] ; then
                duptext=0
            else
                let duptext++
            fi
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
            # Hulu prompt
            if grep "How would you rate your video" $TEMPDIR/${recname}_capture_crop.txt ; then
                echo `$LOGDATE` "Responding to 'How would you rate your video' Prompt"
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
                echo `$LOGDATE` "Recording $RECFILE ended with text screen."
                break 2
            fi
            if (( chapter )) ; then
                sleep 2
                echo `$LOGDATE` "Recording $RECFILE ended at chapter end."
                break 2
            fi

            # If stopped on a text page for 15 iterations (60-90 sec), end recording
            if (( duptext > 15 )) ; then
                echo `$LOGDATE` "Recording $RECFILE ended on static text 15 times."
                break 2
            fi
            # peacock prompt: CANCEL on last line
            # peacock prompt: "Up Next" on a whole line
            # tubi prompt: Starting in xxs or Starting inxs
            # peacock prompt - i TVMA or i TV-14
            # Hulu no ads prompt "Episodes Inside the Episodes"
            # MAX: "AUTOPLAY OFF" or "Next Episode " or "Seasons [0-9]"
            if egrep -a "$endtext" $TEMPDIR/${recname}_capture_crop.txt ; then
                sleep 2
                echo `$LOGDATE` "Recording $RECFILE ended with text prompt."
                break 2
            fi
        fi
        sleep 2
    done
    # maxlowcount default is 15, approx 7.5 minutes, since Amazon end of an episode
    # titles carry on for about 5 minutes.
    if (( lowcount >= maxlowcount )) ; then
        echo `$LOGDATE` "No action on screen, assume recording ended."
        break 2
    fi
    newsize=`stat -c %s "$RECFILE"`
    let diff=newsize-filesize
    filesize=$newsize
    echo `$LOGDATE` "size: $filesize  Incr: $diff"
    if (( diff < MINBYTES )) ; then
        let lowcount++
        echo `$LOGDATE` "Less than MINBYTES ($MINBYTES), lowcount=$lowcount"
        # freevee "Are you still watching" prompt is on a protected screen
        # so look in the file.
        if [[ "$extension" == ts ]] ; then
            capturepage file
            if grep "Are you still watching" $TEMPDIR/${recname}_capture_crop.txt ; then
                echo `$LOGDATE` "Responding to 'Are you still watching?' Prompt"
                $scriptpath/adb-sendkey.sh DPAD_CENTER
            fi
        fi
    else
        lowcount=0
    fi
done
if (( now < minendtime || now < stoptime )) ; then
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
