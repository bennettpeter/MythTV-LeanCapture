#!/bin/bash
# Open usb adapter on vlc
# input parameter - device name leancap1, leancap2 etc.
# Default leancap1

set -e
recname=leancap1

if [[ "$1" != "" ]] ; then
    recname="$1"
fi
. /var/opt/mythtv/$recname.conf 
# Calculate audio offset in ms
eval $(grep ^AUDIO_OFFSET= /etc/opt/mythtv/$recname.conf)
offset_ms=$(echo "$AUDIO_OFFSET * 1000 / 1" | bc)
# Find input format
eval $(grep ^INPUT_FORMAT= /etc/opt/mythtv/$recname.conf)
ifparam=
if [[ "$INPUT_FORMAT" == mjpeg ]] ; then
    ifparam=":v4l2-chroma=MJPG"
fi
if [[ "$AUDIO_IN" != "" ]] ; then
    audio=":input-slave=alsa://$AUDIO_IN"
fi
if [[ "$VIDEO_IN" != "" ]] ; then
    video="v4l2://$VIDEO_IN"
fi
set -x
vlc $video  :v4l2-width=1280 :v4l2-height=720  \
 $ifparam :v4l2-fps=30 :v4l2-aspect-ratio=16:9 $audio \
 --audio-desync $offset_ms
