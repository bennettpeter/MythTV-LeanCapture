#!/bin/bash

# Check favorite channels against upcoming

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

$scriptpath/myth_upcoming_recordings.pl --plain_text --recordings -1 --hours 336 \
  --text_format "%cn\n" | sort -un | tail -n +2 > $DATADIR/recording_channels.txt
rc=$?

if [[ "$rc" != 0 ]] ; then
    $scriptpath/notify.py "Upcoming Recordings Error" \
      "$scriptname failed." &
    exit
fi

chanlistfile=$DATADIR/"$NAVTYPE".txt
wc=$(cat $DATADIR/recording_channels.txt | wc -c)
if (( wc == 0 )) ; then
    $scriptpath/notify.py "Upcoming Recordings Error" \
      "No Upcoming Recordings shown by $scriptname. Possible script error?" &
    exit
fi

# In the diff results-
# Extra channels in favorites will have >, that is OK
# Missing channels in favorites will have < or | , that is not ok
# in both cases the first number on the line is the one wanted
# to be added to favorites

diff -yN $DATADIR/recording_channels.txt "$chanlistfile" > $DATADIR/channel_diff.txt
missing_chans=$(grep "[<|]" $DATADIR/channel_diff.txt | sed "s/ .*//g")
missing_chans=$(echo $missing_chans)
if [[ "$missing_chans" != "" ]] ; then
    $scriptpath/notify.py "Missing Channels" \
      "$scriptname: Channels missing from xfinity favorites: $missing_chans" &
fi
