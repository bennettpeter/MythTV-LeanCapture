#!/bin/bash
# Record from Amazon Prime

title=

minutes=120
recname=leancap1
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
    echo "Record fom Amazon Prime"
    echo "Disable autoplay on Amazon web site"
    echo "Make sure the title you supply shows up as the first result"
    echo "     when searched as <Title Season n>"
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

$scriptpath/adb-sendkey.sh POWER
$scriptpath/adb-sendkey.sh HOME
sleep 0.5

# Check resolution
CROP=" "
capturepage adb
rc=$?
if (( rc == 1 )) ; then exit $rc ; fi

adb -s $ANDROID_DEVICE shell am force-stop com.amazon.firebat
sleep 1
adb -s $ANDROID_DEVICE shell am start -n com.amazon.firebat/.deeplink.DeepLinkRoutingActivity
if ! waitforstring "prime video.* Store.* Channels" "Prime Video" ; then
    exit 2
fi
$scriptpath/adb-sendkey.sh LEFT
if ! waitforstring "Find movies, TV shows, categories, and people\n" Search ; then
    exit 2
fi
echo "Search String: $title Season $season"
adb -s $ANDROID_DEVICE shell input text \""$title Season $season"\"
$scriptpath/adb-sendkey.sh RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT
# Go to result
$scriptpath/adb-sendkey.sh DPAD_CENTER
if ! waitforstring "\n$title\n" "$title" ; then
    exit 2
fi

# Check season
if ! grep "^Season $season" $DATADIR/${recname}_capture_crop.txt ; then
    echo `$LOGDATE` "ERROR - Wrong Season Selected"
    exit 2
fi
# Go to episodes of this season
$scriptpath/adb-sendkey.sh DPAD_CENTER
if ! waitforstring "Seasons &" "Season Detail"; then
    exit 2
fi
# Go to seasons & Episodes
$scriptpath/adb-sendkey.sh RIGHT RIGHT RIGHT RIGHT
$scriptpath/adb-sendkey.sh LEFT
$scriptpath/adb-sendkey.sh DPAD_CENTER

if ! waitforstring "\nSeason $season, Episode [0-9][0-9]*" "Episode" ; then
    exit 2
fi
# See what episode we are on
sep=($(grep -o -m 1 "^Season $season, Episode [0-9][0-9]*" $DATADIR/${recname}_capture_crop.txt))
epfound=${sep[3]}
if [[ "$epfound" == "" ]] ; then
    echo `$LOGDATE` "ERROR - Cannot see what episode was selected"
    exit 2
fi
echo `$LOGDATE` "Season $season, Episode $epfound is selected"
let diff=episode-epfound
if (( diff < 0 )) ; then
    let diff=-diff
    for (( x=0; x<diff; x++)) ; do
        $scriptpath/adb-sendkey.sh LEFT
    done
elif (( diff > 0 )) ; then
    for (( x=0; x<diff; x++)) ; do
        $scriptpath/adb-sendkey.sh RIGHT
    done
fi
if ! waitforstring "\nSeason $season, Episode $episode" "Season $season, Episode $episode" ; then
    exit 2
fi

subtitle=
# This gives the subtitle plus first sentence of description. Not useful.
#~ subtitle=$(grep -m 1 "^Season $season, Episode $episode - " $DATADIR/${recname}_capture_crop.txt \
    #~ | sed "s/^Season $season, Episode $episode - //")
echo "subtitle: $subtitle"
duration="20min"
orig_airdate=
# This extracts duration and orig air date but is not reliable
#~ dirtim=($(grep -E -m 1 "^[0-9][0-9]* *min|^[0-9][0-9]* *hr" $DATADIR/${recname}_capture_crop.txt))
#~ size=${#dirtim[@]}
#~ duration="${dirtim[@]:0:size-3}"
#~ orig_aridate="${dirtim[@]:size-3:3}"

# Replace slashes with dashes and lose extra spaces including leading space
subtitle=$(echo $subtitle | sed "s@/@-@g")

if [[ "$orig_airdate" != "" ]] ; then
    orig_airdate=$(date -d "$orig_airdate" "+%y%m%d")
fi

let durationsecs=$(date -d "1970-01-01 $duration" +%s)-$(date -d "1970-01-01" +%s)

echo "Episode duration: $duration"

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
if [[ "$subtitle" != "" ]] ; then
    subtitle=" $subtitle"
fi
recfilebase="$VID_RECDIR/$title/$orig_airdate$season_episode$subtitle"
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
if (( durationsecs == 0 )) ; then
    duration=maxduration
fi
let endtime=starttime+durationsecs
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
echo `$LOGDATE` "Complete - Recorded"
