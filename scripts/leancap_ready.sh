#!/bin/bash

# Initialize android device and make it ready for tuning
# Keep the device on favorite channel list.

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

recname="$1"
if [[ "$recname" == "" ]] ; then
    recname=leancap1
fi
capseq="$2"

source $scriptpath/leanfuncs.sh

SLEEPTIME=300
initialize

# tunestatus values
# idle
# tuned
sleep 2
errored=0
lastrescheck=
lastfavcheck=
startup=$(date +%s)
while true ; do
    if ! locktuner ; then
        echo `$LOGDATE` "Encoder $recname is already locked, waiting"
        sleep $SLEEPTIME
        continue
    fi
    mrc=0
    gettunestatus
    # Stopped more than 5 minutes ago and not playing - tweak it
    now=$(date +%s)
    if (( tunetime < now-300 )) && [[ "$tunestatus" == idle ]] ; then
        getparms
        rc=$?
        if (( rc > mrc )) ; then mrc=$rc ; fi
        if (( rc > errored )) ; then
            $scriptpath/notify.py "Fire Stick Problem" \
                "leancap_ready: $errormsg on ${recname}" &
            errored=$rc
        fi
        today=$(date +%Y-%m-%d)
        adb connect $ANDROID_DEVICE
        if [[ "$lastrescheck" != "$today" ]] ; then
            # At least once a day, check resolution and restart
            # Xfinity app
            errored=0
            # Uncomment this to only call the fixresolution if there is an error
            # Better not to do this so I can get early warning of aany UI
            # Change that makes this not work.
            #~ capturepage adb
            #~ rc=$?
            #~ if (( rc == 1 )) ; then
            fireresolution
            rc=$?
            if (( rc != 0 )) ; then
                $scriptpath/notify.py "Fire Stick Problem" \
                  "leancap_ready: Cannot set resolution on ${recname}" &
            fi
            #~ else
                #~ $scriptpath/adb-sendkey.sh POWER
                #~ $scriptpath/adb-sendkey.sh HOME
            #~ fi
            lastrescheck="$today"
        fi
        # Only check this on one tuner
        if (( capseq == 1 )) ; then
            # Only check once per day
            if [[ "$NAVTYPE" == "Favorite Channels" \
                && "$lastfavcheck" != "$today" ]] ; then
                # Simple check for mythbackend running
                if (( now - startup > 300 )) && pidof mythbackend >/dev/null ; then
                    $scriptpath/leancap_checkfavorites.sh
                    lastfavcheck="$today"
                fi
            fi
        fi
        $scriptpath/adb-sendkey.sh MENU
        $scriptpath/adb-sendkey.sh LEFT
        $scriptpath/adb-sendkey.sh RIGHT
        navigate "$NAVTYPE" "$NAVKEYS"
        rc=$?
        if (( rc > mrc )) ; then mrc=$rc ; fi
        if (( rc > errored ))  ; then
            $scriptpath/notify.py "Fire Stick Problem" \
              "leancap_ready: Failed to get to favorite channels on ${recname}" &
            errored=$rc
        fi
        # If no error this entire run, reset errored so messages can resume.
        if (( mrc == 0 )) ; then
            errored=0
        fi
        adb disconnect $ANDROID_DEVICE
    else
        echo `$LOGDATE` "Encoder $recname is tuned, waiting"
    fi
    unlocktuner
    sleep $SLEEPTIME
done
