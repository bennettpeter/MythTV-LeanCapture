#!/bin/bash
# Record from xfinity on demand

title=

minutes=360
recname=leancap1
ADB_ENDKEY=
waitforstart=1
season=
episode=
wait=0

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
      || "$episode" == "" ]] ; then
    echo "*** $0 ***"
    echo "Input parameters:"
    echo "--title|-t xxxx : Title"
    echo "--time nn : Maximum Number of minutes [default 360]"
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

# Force a launch first to get to the stNDRd start page
$scriptpath/adb-sendkey.sh DOWN
sleep 1

# Check resolution
CROP=" "
capturepage adb
rc=$?
if (( rc == 1 )) ; then exit $rc ; fi

navigate Search
sleep 1
if [[ "$pagename" != Search* ]] ; then
    echo `$LOGDATE` "ERROR: Unable to get to Search Keyboard"
    exit 2
fi

echo "Search String: $title"
adb -s $ANDROID_DEVICE shell input text \""$title"\"
$scriptpath/adb-sendkey.sh MEDIA_PLAY_PAUSE
sleep 1
$scriptpath/adb-sendkey.sh DOWN
$scriptpath/adb-sendkey.sh DOWN
$scriptpath/adb-sendkey.sh DPAD_CENTER
CROP="-gravity NorthWest -crop 70%x10%"
if ! waitforpage "$title" ; then
    echo `$LOGDATE` "ERROR: Unable to get to $title"
    exit 2
fi

# Unzoom the top line
$scriptpath/adb-sendkey.sh DPAD_CENTER
sleep 2
CROP="-gravity SouthEast -crop 70%x100%"
capturepage
# In case it got into "Set Series recording" by accident
if grep "Set Series Recording" $TEMPDIR/${recname}_capture_crop.txt ; then
    $scriptpath/adb-sendkey.sh BACK
    $scriptpath/adb-sendkey.sh UP
    $scriptpath/adb-sendkey.sh RIGHT
    $scriptpath/adb-sendkey.sh DPAD_CENTER
    CROP="-gravity SouthEast -crop 70%x100%"
    capturepage
fi
top=($(grep -m 1 Season $TEMPDIR/${recname}_capture_crop.txt))
let topseason=top[1]
let diff=topseason-season
if (( diff < 0 )) ; then
    echo `$LOGDATE` "ERROR: Invalid season $season"
    exit 2
fi
    
if (( diff > 0 )) ; then
    keypress=
    for (( xy=0; xy<diff; xy++ )) ; do
        $scriptpath/adb-sendkey.sh DOWN
    done
fi
sleep 2
CROP="-gravity SouthEast -crop 70%x100%"
capturepage
if ! grep "Season $season" $TEMPDIR/${recname}_capture_crop.txt ; then
    echo `$LOGDATE` "ERROR: Cannot find season $season"
    exit 2
fi
# Expand the season
$scriptpath/adb-sendkey.sh DPAD_CENTER
sleep 4
#Get to first ep
if (( diff > 0 )) ; then
    keypress=
    for (( xy=0; xy<diff; xy++ )) ; do
        $scriptpath/adb-sendkey.sh DOWN
    done
fi
$scriptpath/adb-sendkey.sh DOWN
CROP="-gravity SouthEast -crop 70%x100%"
capturepage
top=($(grep -m 1 ^Ep[0-9] $TEMPDIR/${recname}_capture_crop.txt))
#~ let topepisode=${top[0]#Ep}
topepisode=${top[0]#Ep}
topepisode=${topepisode%%[^0-9]*}
if (( topepisode == 0 )) ; then
    echo `$LOGDATE` "ERROR: Cannot find episode in $top"
    exit 2
fi
let diff=topepisode-episode
if (( diff < 0 )) ; then
    echo `$LOGDATE` "ERROR: Invalid episode $episode"
    exit 2
fi
    
if (( diff > 0 )) ; then
    keypress=
    for (( xy=0; xy<diff; xy++ )) ; do
        $scriptpath/adb-sendkey.sh DOWN
    done
fi
sleep 2
CROP="-gravity SouthEast -crop 70%x100%"
capturepage
#~ if ! grep "^Ep$episode" $TEMPDIR/${recname}_capture_crop.txt ; then
    #~ echo `$LOGDATE` "ERROR: Cannot find episode $episode"
    #~ exit 2
#~ fi

# Expand the episode
$scriptpath/adb-sendkey.sh DPAD_CENTER
sleep 1
CROP="-gravity SouthEast -crop 70%x100%"
capturepage
match=0
subtitle=$(grep "^Ep$episode " $TEMPDIR/${recname}_capture_crop.txt)
if [[ "$subtitle" == Ep${episode}* ]] ; then
    match=1
fi
# In case it misinterpreted 7 as /
if (( ! match && episode == 7)) ; then
    subtitle=$(grep "^Ep/ " $TEMPDIR/${recname}_capture_crop.txt)
    if [[ "$subtitle" == Ep/* ]] ; then
        match=1
    fi
fi
# In case it misinterpreted 7 as 7/
if (( ! match && episode == 7)) ; then
    subtitle=$(grep "^Ep7/ " $TEMPDIR/${recname}_capture_crop.txt)
    if [[ "$subtitle" == Ep7/* ]] ; then
        match=1
    fi
fi
# In case it misinterpreted 7 as ?
if (( ! match && episode == 7)) ; then
    subtitle=$(grep "^Ep? " $TEMPDIR/${recname}_capture_crop.txt)
    if [[ "$subtitle" == Ep* ]] ; then
        match=1
    fi
fi
if (( !match )) ; then
    echo `$LOGDATE` "ERROR: Cannot find episode $episode details"
    exit 2
fi
subtitle=${subtitle#Ep* }
# Replace slashes with dashes and lose extra spaces
subtitle=$(echo $subtitle | sed "s@/@-@g")

# Use only 1 slash because if it is the current year they do not show
# the year.
orig_airdate=$(grep -o "([0-9]*/[0-9/]*)" $TEMPDIR/${recname}_capture_crop.txt)
if [[ "$orig_airdate" != "" ]] ; then
    orig_airdate=${orig_airdate#(}
    orig_airdate=${orig_airdate%)}
    orig_airdate=$(date -d "$orig_airdate" "+%y%m%d")
fi

duration=$(grep -o "[0-9]*min$" $TEMPDIR/${recname}_capture_crop.txt)
duration=${duration%min}
echo "Episode duration: $duration minutes"

if (( ${#season} == 1 )) ; then
    season=0$season
fi
if (( ${#episode} == 1 )) ; then
    episode=0$episode
fi
season_episode=S${season}E${episode}

# Add a space if there is an airdate
if [[ "$orig_airdate" != "" ]] ; then
    orig_airdate="$orig_airdate "
fi

recfilebase="$VID_RECDIR/$title/$orig_airdate$season_episode $subtitle"
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
-preset $X264_PRESET \
-crf $X264_CRF \
-c:a aac \
"$recfile" &

ffmpeg_pid=$!
starttime=`date +%s`
sleep 10
capturepage adb
# Get past resume prompt and start over
if [[ `stat -c %s $TEMPDIR/${recname}_capture_crop.png` != 0 ]] ; then
    if  grep "Resume" $TEMPDIR/${recname}_capture_crop.txt \
        ||  grep "Start" $TEMPDIR/${recname}_capture_crop.txt ; then
        echo `$LOGDATE` "Selecting Start Over from Resume Prompt"
        $scriptpath/adb-sendkey.sh DOWN
        $scriptpath/adb-sendkey.sh DPAD_CENTER
        starttime=`date +%s`
    fi
fi
sleep 10
let maxduration=minutes*60
let maxendtime=starttime+maxduration
if (( duration == 0 )) ; then
    duration=maxduration
fi
let endtime=starttime+duration

filesize=0
lowcount=0
let minbytes=MINBYTES*2
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
    if [[ "$pagename" != "" ]] || (( lowcount > 0 && now > endtime )) || (( lowcount > 4 )) ; then
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
    if (( diff < minbytes )) ; then
        let lowcount++
        echo `$LOGDATE` "Less than $minbytes, lowcount=$lowcount"
    else
        lowcount=0
    fi
done
echo `$LOGDATE` "Complete - Recorded"
