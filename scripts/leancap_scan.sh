#!/bin/bash

# Scan External Recorder Tuners and setup devices
# Tuners must be set up with files called /etc/opt/mythtv/leancap*.conf
# This will create files /var/opt/mythtv/leancap*.conf
# with VIDEO_IN and AUDIO_IN settings
# 

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/leanfuncs.sh

initialize

if ! ls /etc/opt/mythtv/leancap?.conf ; then
    echo No Leancap recorders, exiting
    exit 2
fi

reqname="$1"
if [[ "$reqname" == "" ]] ; then
    reqname=leancap?
fi

# Quickly lock all the tuners
for conffile in /etc/opt/mythtv/$reqname.conf ; do
    echo $conffile found
    if [[ "$conffile" == "/etc/opt/mythtv/$reqname.conf" ]] ; then
        echo `$LOGDATE` "Warning - No leancap recorder found"
        exit
    fi
    recname=$(basename $conffile .conf)

    if ! locktuner ; then
        echo `$LOGDATE` "ERROR Encoder $recname is already locked - abort."
        exit 2
    fi
done

# set all tuners to HOME
for conffile in /etc/opt/mythtv/$reqname.conf ; do
    echo $conffile found
    recname=$(basename $conffile .conf)

    tunefile=$DATADIR/${recname}_tune.stat
    # Clear status
    true > $tunefile

    getparms
    rc=$?
    if [[ "$ANDROID_DEVICE" == "" ]] ; then
        continue
    fi
    if (( rc > 0 )) ; then
        $scriptpath/notify.py "Fire Stick Problem" \
          "leancap_scan: Primary network adapter for $recname failed" &
    fi
    adb connect $ANDROID_DEVICE
    sleep 0.5
    res=(`adb devices|grep $ANDROID_DEVICE`)
    status=${res[1]}
    if [[ "$status" != device ]] ; then
        echo `$LOGDATE` "WARNING: Device offline: $recname, skipping"
        $scriptpath/notify.py "Fire Stick Problem" \
          "leancap_scan: Device offline: $recname" &
        adb disconnect $ANDROID_DEVICE
        continue
    fi
    $scriptpath/adb-sendkey.sh POWER
    $scriptpath/adb-sendkey.sh HOME
    adb disconnect $ANDROID_DEVICE
done

capseq=0
pidlist=
# Invoke app and check where the result is
for conffile in /etc/opt/mythtv/$reqname.conf ; do
    recname=$(basename $conffile .conf)
    true > $DATADIR/${recname}.conf
    getparms
    if [[ "$ANDROID_DEVICE" == "" ]] ; then
        unlocktuner
        continue
    fi
    adb connect $ANDROID_DEVICE
    sleep 0.5

    res=(`adb devices|grep $ANDROID_DEVICE`)
    status=${res[1]}
    if [[ "$status" != device ]] ; then
        echo `$LOGDATE` "WARNING: Device offline: $recname, skipping"
        adb disconnect $ANDROID_DEVICE
        unlocktuner
        continue
    fi

    echo `$LOGDATE` "Reset recorder: $recname"
    launchXfinity
    sleep 2
    match=N
    for trynum in 1 2 3 4 5; do
        for (( x=0; x<20; x=x+2 )) ; do
            VIDEO_IN=/dev/video${x}
            if [[ ! -e $VIDEO_IN ]] ; then continue ; fi
            echo `$LOGDATE` "Trying: $VIDEO_IN"
            capturepage video
            if [[ "$pagename" == "For You" ]] ; then
                match=Y
                break
            elif [[ "$pagename" == "We"*"detect your remote" ]] ; then
                $scriptpath/adb-sendkey.sh DPAD_CENTER
                sleep 1
            fi
            sleep 1
        done
        if [[ $match == Y ]] ; then break ; fi
        echo `$LOGDATE` "Failed to read screen on ${recname}, trying again"
        sleep 1
    done

    if [[ $match != Y ]] ; then
        echo `$LOGDATE` "Failed to start XFinity on ${recname} - see $DATADIR/${recname}_capture.png"
        $scriptpath/notify.py "Fire Stick Problem" \
          "leancap_scan: Failed to start XFinity on ${recname}" &
        $scriptpath/adb-sendkey.sh HOME
        adb disconnect $ANDROID_DEVICE
        unlocktuner
        continue
    fi
    # We have the video device,now get the audio device
    $scriptpath/adb-sendkey.sh HOME
    adb disconnect $ANDROID_DEVICE

    # vid_path is a string like pci-0000:00:14.0-usb-0:2.2:1.0
    vid_path=$(udevadm info --query=all --name=$VIDEO_IN|grep "ID_PATH="|sed s/^.*ID_PATH=//)
    len=${#vid_path}
    AUDIO_IN=
    vid_path=${vid_path:0:len-1}
    audiodev=$(readlink /dev/snd/by-path/${vid_path}?)
    if [[ "$audiodev" != ../controlC* ]] ; then
        echo `$LOGDATE` "ERROR Failed to find audio device for $VIDEO_IN"
        unlocktuner
        continue
    fi
    AUDIO_IN="hw:"${audiodev#../controlC},0

    echo "VIDEO_IN=$VIDEO_IN" > $DATADIR/${recname}.conf
    echo "AUDIO_IN=$AUDIO_IN" >> $DATADIR/${recname}.conf
    echo `$LOGDATE` Successfully created parameters in $DATADIR/${recname}.conf.
    unlocktuner
    # When rinnung as a service, start up the leancap_ready processes
    if (( ! isterminal )) ; then
        # script that runs forever to keep device in a ready state
        let capseq++
        $scriptpath/leancap_ready.sh $recname $capseq &
        pidlist="$pidlist $!"
    fi
done

$LOGDATE > $LOCKBASEDIR/scandate

if [[ "$pidlist" != "" ]] ; then
    # wait for any ready process to end
    wait -n $pidlist
    # kill all ready processes if one ends
    kill $pidlist
fi
