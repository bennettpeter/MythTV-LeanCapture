#!/bin/bash

# External Recorder Encoder
# Parameter 1 - recorder name

# This script must write nothing to stdout other than the encoded data.
recname=$1

. /etc/opt/mythtv/leancapture.conf
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

progressfile=$TEMPDIR/${scriptname}_${recname}_progress.log
echo `$LOGDATE` "Start ffmpeg channel $tunechan" > $progressfile

ffmpeg -hide_banner -loglevel error -f v4l2 -thread_queue_size 256 -input_format $INPUT_FORMAT \
  -framerate $FRAMERATE -video_size $RESOLUTION \
  -use_wallclock_as_timestamps 1 \
  -i $VIDEO_IN -f alsa -ac 2 -ar 48000 -thread_queue_size 1024 \
  -itsoffset $AUDIO_OFFSET -i $AUDIO_IN \
  -c:v libx264 -vf format=yuv420p -preset $X264_PRESET -crf $X264_CRF -c:a aac \
  -f mpegts - | pv -b -n -i 30 2>> $progressfile &

# This is actually the pv pid, but killing pv kills ffmpeg so all is ok.
ffmpeg_pid=$!

# Alternative but unnecessary way of getting actual ffmpeg pid
#~ sleep 1
#~ psresult=($(ps -o pid,cmd --no-headers  --ppid $$ | grep ffmpeg | grep -v grep))
#~ ffmpeg_pid=${psresult[0]}

echo tune_ffmpeg_pid=$ffmpeg_pid >> $tunefile

{
    sleep 20
    adb connect $ANDROID_DEVICE
    # Loop to check if recording is working.
    # When recording is working, nothing is displayed
    # from capture. If anything is captured, something
    # went wrong.
    errored=0
    lowcount=0
    while (( 1 )) ; do
        if ! ps -q $ffmpeg_pid >/dev/null ; then
            echo `$LOGDATE` "ffmpeg terminated"
            break
        fi
        #~ capturepage adb
        #~ # Possible pagenames - "Playback Issue"* or name of a show
        #~ if [[ "$pagename" != "" ]] ; then
            #~ echo `$LOGDATE` "ERROR: playback failed, retrying."
            #~ if (( errored == 0 )) ; then
                #~ $scriptpath/notify.py "Xfinity Problem" \
                    #~ "leancap_encode: Playback Failed on ${recname}, retrying" &
            #~ fi
            #~ let errored++
            #~ # Try to tune again
            #~ $scriptpath/adb-sendkey.sh BACK
            #~ sleep 1
            #~ $scriptpath/leancap_tune.sh $recname $tunechan NOLOCK
        #~ fi
        size=($(tail -2 $progressfile))
        # numeric check
        if [[ "${size[0]}" =~ ^[0-9]+$ && "${size[1]}" =~ ^[0-9]+$ ]] ; then
            let diff=size[1]-size[0]
            echo `$LOGDATE` "Size: ${size[1]} Incr: $diff"
            if (( diff < MINBYTES )) ; then
                let lowcount=lowcount+1
                if (( lowcount > 3 )) ; then
                    # 4 in a row.
                    echo `$LOGDATE` "ERROR: increment less that $MINBYTES, retrying."
                    if (( errored == 0 )) ; then
                        $scriptpath/notify.py "Xfinity Problem" \
                            "leancap_encode: Playback Failed on ${recname}, retrying" &
                        errored=1
                    fi
                    echo "$tunechan $(date -u '+%Y-%m-%d %H:%M:%S')" \
                        >> $TEMPDIR/${recname}_damage.txt
                    # Try to tune again
                    launchXfinity
                    sleep 2
                    $scriptpath/leancap_tune.sh $recname $tunechan NOLOCK
                    lowcount=0
                fi
            else
                lowcount=0
            fi
        fi
        sleep 30
    done
} &>> $logfile

