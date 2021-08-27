#!/bin/bash

# External Recorder Tuner
# Parameter 1 - recorder name
# Parameter 2 - channel number
# Parameter 3 - LOCK or NOLOCK, default is LOCK

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

case "$NAVTYPE" in
    "Favorite Channels")
        exec $scriptpath/leancap_tune_fav.sh "$@"
        ;;
    "All Channels")
        exec $scriptpath/leancap_tune_all.sh "$@"
        ;;
    *)
        exec $scriptpath/leancap_tune_all.sh "$@"
        ;;
esac
