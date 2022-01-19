#!/bin/bash
# Record from Paramount Plus

title=

minutes=120
recname=leancap1
endkey=HOME
waitforstart=1
season=
episode=
wait=0
fseason=0
fdesc=

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
        --fseason|-F)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                fseason="$2"
                shift||rc=$?
            fi
            ;;
        --fdesc|-D)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for $1" ; error=y
            else
                fdesc="$2"
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

if (( season < fseason )) ; then
    echo "ERROR Season cannot be less than first season"
    error=y
fi

if [[ "$error" == y || "$title" == "" || "$season" == "" \
      || "$episode" == "" || $fseason == "" || $fdesc == "" ]] ; then
    echo "*** $0 ***"
    echo "Record fom Paramount Plus"
    echo "Disable autoplay on Paramount Plus"
    echo "Make sure the title you supply shows up as the first result"
    echo "Input parameters:"
    echo "--title|-t xxxx : Title"
    echo "--time nn : Maximum Number of minutes [default 120]"
    echo "--recname|-n xxxxxxxx : Recorder id (default leancap1)"
    echo "--season|-S nn : Season without leading zeroes"
    echo "--episode|-E nn : Episode without leading zeroes"
    echo "--wait : Pause immediately before playback, for testing"
    echo "    or to rewind in progress show to beginning."
    echo "--fseason|-F nn : First season available on Paramount Plus"
    echo "--fdesc|-D xxxx : A phrase from the descriptions that appear on the"
    echo "    first page of episodes, to check if the correct page is found"
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
ADB_ENDKEY=HOME
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
adb -s $ANDROID_DEVICE shell am force-stop com.cbs.ott
sleep 1
adb -s $ANDROID_DEVICE shell am start -n com.cbs.ott/com.cbs.app.tv.ui.activity.SplashActivity
if ! waitforstring "CBS.*\n" Paramount ; then
    exit 2
fi
$scriptpath/adb-sendkey.sh LEFT
$scriptpath/adb-sendkey.sh LEFT
if ! waitforstring "\nSearch\nHome\n" Menu ; then
    exit 2
fi
$scriptpath/adb-sendkey.sh UP
$scriptpath/adb-sendkey.sh DPAD_CENTER
$scriptpath/adb-sendkey.sh DPAD_CENTER
#~ if ! waitforstring "\nPress and hold . to say words and phrases\n" Keyboard 
if ! waitforstring "Delete" Keyboard ; then
    exit 2
fi

echo "Search String: $title"
adb -s $ANDROID_DEVICE shell input text \""$title"\"
$scriptpath/adb-sendkey.sh MEDIA_PLAY_PAUSE
str=
len=${#title}
for (( x=0; x<len; x++)) ; do
    str="$str RIGHT"
done
if [[ $str != "" ]] ; then $scriptpath/adb-sendkey.sh $str ; fi
# Go to result
$scriptpath/adb-sendkey.sh RIGHT
# Select first item
$scriptpath/adb-sendkey.sh DPAD_CENTER
if ! waitforstring "\nEpisodes\n" "$title" ; then
    exit 2
fi
# Down to episodes
$scriptpath/adb-sendkey.sh DOWN
$scriptpath/adb-sendkey.sh DPAD_CENTER
if ! waitforstring "\nSeason" "Episodes" ; then
    exit 2
fi
# Go to seasons
$scriptpath/adb-sendkey.sh LEFT
$scriptpath/adb-sendkey.sh LEFT

#Get to correct season
let lineno=season-fseason
str=
# Get to top of list with 20 UPs
for (( x=0; x<20; x++)) ; do
    str="$str UP"
done
if [[ $str != "" ]] ; then $scriptpath/adb-sendkey.sh $str ; fi
$scriptpath/adb-sendkey.sh DPAD_CENTER
CROP="-gravity East -crop 40%x100%"
if ! waitforstring "$fdesc" "Description ($fdesc)" adb ; then
    exit 2
fi
$scriptpath/adb-sendkey.sh LEFT
$scriptpath/adb-sendkey.sh LEFT
str=
for (( x=0; x<lineno; x++)) ; do
    str="$str DOWN"
done
if [[ $str != "" ]] ; then $scriptpath/adb-sendkey.sh $str ; fi
# Go to episodes of that season
$scriptpath/adb-sendkey.sh DPAD_CENTER
sleep 5
#Get to correct episode
str=
for (( x=1; x<episode; x++)) ; do
    str="$str DOWN"
done
if [[ $str != "" ]] ; then $scriptpath/adb-sendkey.sh $str ; fi
CROP="-gravity East -crop 40%x100%"
# Wait for episode to scroll into view
sleep 5
capturepage adb
if (( episode == 1 )) ; then
    srchstring="^1\.|^4\.|^41\."
elif (( episode == 10 )) ; then
    srchstring="^10\.|^410\."
else
    srchstring="^$episode\."
fi

subtitle=$(grep -E -m 1 "$srchstring" $DATADIR/${recname}_capture_crop.txt | sed "s/[0-9]*\.//")
echo "subtitle: $subtitle"
lineno=$(grep -E -m 1 -n "$srchstring" $DATADIR/${recname}_capture_crop.txt | sed "s/:.*//")
#default duration
duration="20min"
orig_airdate=
if (( lineno > 0 )) ; then
    dattim=$(sed -n "$lineno,999p" $DATADIR/${recname}_capture_crop.txt | grep -m 1 " [0-9][0-9]*min ")
    duration=$(echo "$dattim" | grep -o " [0-9][0-9]*min ")
    orig_airdate=$(echo "$dattim" | sed "s/$duration.*//")
    if echo $orig_airdate | grep "[0-9],[0-9]" ; then
        # fix Jun 24,2021 to Jun 24, 2021 as the former is invalid for date
        orig_airdate=$(echo $orig_airdate | sed "s/,/, /")
    fi
    # Remove any apostrophe
    orig_airdate=$(echo $orig_airdate | sed "s/'//g")
    echo "origdate: $orig_airdate"
fi
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
-crf 23 \
-c:a aac \
"$recfile" &

sizelog=$VID_RECDIR/$($LOGDATE)_size.log
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
    echo `$LOGDATE` "size: $filesize  Incr: $diff" >> "$sizelog"
    if (( diff < 5000000 )) ; then
        let lowcount++
        echo "*** Less than 5 MB *** lowcount=$lowcount" >> "$sizelog"
        echo `$LOGDATE` "Less than 5 MB, lowcount=$lowcount"
    else
        lowcount=0
    fi
done
echo `$LOGDATE` "Complete - Recorded"
