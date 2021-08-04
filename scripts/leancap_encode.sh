#!/bin/bash

# External Recorder Encoder
# Parameter 1 - recorder name

# This script must write nothing to stdout other than the encoded data.
recname=$1

. /etc/opt/mythtv/leancap.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
source $scriptpath/leanfuncs.sh
ffmpeg_pid=
logfile=$LOGDIR/${scriptname}_${recname}.log
{
    initialize NOREDIRECT
    getparms
    if ! locktuner 120 ; then
        echo `$LOGDATE` "Unable to lock tuner $recname - aborting"
        exit 2
    fi
    gettunestatus

    # tunestatus values
    # idle
    # tuned

    if [[ "$tunestatus" == tuned  ]] ; then
        echo `$LOGDATE` "Tuned to channel $tunechan"
    else
        echo `$LOGDATE` "ERROR: Not tuned, status $tunestatus, cannot record"
        exit 2
    fi

    adb connect $ANDROID_DEVICE
    if ! adb devices | grep $ANDROID_DEVICE ; then
        echo `$LOGDATE` "ERROR: Unable to connect to $ANDROID_DEVICE"
        exit 2
    fi

    if [[ "$AUDIO_OFFSET" == "" ]] ; then
        AUDIO_OFFSET=0.150
    fi
} &>> $logfile

# Update the tune time at end
updatetunetime=1

ffmpeg -hide_banner -loglevel error -f v4l2 -thread_queue_size 256 -input_format $INPUT_FORMAT \
  -framerate $FRAMERATE -video_size $RESOLUTION \
  -use_wallclock_as_timestamps 1 \
  -i $VIDEO_IN -f alsa -ac 2 -ar 48000 -thread_queue_size 1024 \
  -itsoffset $AUDIO_OFFSET -i $AUDIO_IN \
  -c:v libx264 -vf format=yuv420p -preset faster -crf 23 -c:a aac \
  -f mpegts - &

ffmpeg_pid=$!
echo tune_ffmpeg_pid=$ffmpeg_pid >> $tunefile

{
    sleep 20
    adb connect $ANDROID_DEVICE
    capturepage adb
    # Possible pagenames - "Playback Issue"* or name of a show
    if [[ "$pagename" != "" ]] ; then
        echo `$LOGDATE` "ERROR: playback failed, retrying."
        $scriptpath/notify.py "Xfinity Problem" \
            "leancap_encode: Playback Failed on ${recname}, retrying" &
        # Try to tune again, once only.
        $scriptpath/leancap_tune.sh $recname $tunechan NOLOCK
    fi
} &>> $logfile

wait $ffmpeg_pid
