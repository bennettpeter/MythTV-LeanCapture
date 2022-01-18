#!/bin/bash
# Open usb adapter on vlc
# input parameter - device name leancap1, leancap2 etc.
# Default leancap1

recname=leancap1

if [[ "$1" != "" ]] ; then
    recname="$1"
fi

. /var/opt/mythtv/$recname.conf 
audio=":input-slave=alsa://$AUDIO_IN"
video="v4l2://$VIDEO_IN"
vlc $video  :v4l2-width=1280 :v4l2-height=720  \
 :v4l2-chroma=BGR3 :v4l2-fps=30 :v4l2-aspect-ratio=16:9 $audio
