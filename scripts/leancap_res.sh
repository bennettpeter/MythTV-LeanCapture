#!/bin/bash

# Check and fix resolution on fire tv stick

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

recname="$1"
if [[ "$recname" == "" ]] ; then
    recname=leancap1
fi

source $scriptpath/leanfuncs.sh
initialize
getparms
rc=$?
if (( rc > 1 )) ; then exit $rc ; fi
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
fireresolution
rc=$?
exit $rc
