#!/bin/bash

# Scan External Recorder Tuners and setup devices
# Tuners must be set up with files called /etc/opt/mythtv/leancap*.conf
# This will create files /var/opt/mythtv/leancap*.conf
# with VIDEO_IN and AUDIO_IN settings
# This uses the SLEEP and WAKEUP commands to create a screen display
# which is then checked.
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
    if [[ ! -f "$conffile" ]] ; then
        echo `$LOGDATE` "Warning - $conffile not found"
        exit
    fi
    recname=$(basename $conffile .conf)

    if ! locktuner ; then
        echo `$LOGDATE` "ERROR Encoder $recname is already locked - abort."
        exit 2
    fi
done

# set all tuners to SLEEP
for conffile in /etc/opt/mythtv/$reqname.conf ; do
    echo $conffile found
    recname=$(basename $conffile .conf)

    tunefile=$TEMPDIR/${recname}_tune.stat
    # Clear status
    true > $tunefile

    getparms
    rc=$?
    if [[ "$ANDROID_DEVICE" == "" ]] ; then
        continue
    fi
    if (( rc > 0 )) ; then
        $scriptpath/notify.py "Fire Stick Problem" \
          "leancap_scan: Primary network adapter for $recname failed"
    fi
    adb connect $ANDROID_DEVICE
    sleep 0.5
    res=(`adb devices|grep $ANDROID_DEVICE`)
    status=${res[1]}
    if [[ "$status" != device ]] ; then
        echo `$LOGDATE` "WARNING: Device offline: $recname, skipping"
        $scriptpath/notify.py "Fire Stick Problem" \
          "leancap_scan: Device offline: $recname"
        adb disconnect $ANDROID_DEVICE
        continue
    fi
    $scriptpath/adb-sendkey.sh SLEEP
    adb disconnect $ANDROID_DEVICE
    sleep 0.5
done

# check all video devices for off
sleep 2
for (( x=0; x<20; x=x+2 )) ; do
    VIDEO_IN=/dev/video${x}
    if [[ ! -e $VIDEO_IN ]] ; then continue ; fi
    echo `$LOGDATE` "Trying: $VIDEO_IN"
    success=0
    for (( ix=1; ix<5; ix++ )) ; do
        CROP=" "
        capturepage video
        if [[ `stat -c %s $TEMPDIR/${recname}_capture_crop.txt` > 0 ]] ; then
            echo `$LOGDATE` "ERROR: Device: $VIDEO_IN has stuff on screen."
            sleep 1
        else
            echo "$VIDEO_IN is blank."
            success=1
            break
        fi
    done
    set -x
    if (( ! success )) ; then
        $scriptpath/notify.py "Fire Stick Problem" \
          "leancap_scan: ERROR, Device $VIDEO_IN has stuff on screen after several tries."
        exit 2
    fi
done

capseq=0
pidlist=
assigned=
# Got to HOME and see if it responds
for conffile in /etc/opt/mythtv/$reqname.conf ; do
    recname=$(basename $conffile .conf)
    getparms
    if [[ "$ANDROID_DEVICE" == "" ]] ; then
        unlocktuner
        # No device in configuration - clear out audio and video settings.
        true > $DATADIR/${recname}.conf
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
    $scriptpath/adb-sendkey.sh WAKEUP
    $scriptpath/adb-sendkey.sh HOME
    sleep 2
    match=N
    remotefix=
    for (( trynum = 0; trynum < 5; trynum++ )) ; do
        for (( x=0; x<20; x=x+2 )) ; do
            VIDEO_IN=/dev/video${x}
            # Ignore already used ports
            if [[ "$assigned" == *"$VIDEO_IN"* ]] ; then continue ; fi
            if [[ ! -e $VIDEO_IN ]] ; then continue ; fi
            echo `$LOGDATE` "Trying: $VIDEO_IN"
            CROP=" "
            capturepage video
            if [[ `stat -c %s $TEMPDIR/${recname}_capture_crop.txt` > 0 ]] ; then
                match=Y
                break;
            fi
            sleep 2
        done
        if [[ $match == Y ]] ; then break ; fi
        echo `$LOGDATE` "Failed to read screen on ${recname}, trying again"
        sleep 2
    done

    if [[ $match != Y ]] ; then
        echo `$LOGDATE` "Failed to identify ${recname}."
        $scriptpath/notify.py "Fire Stick Problem" \
          "leancap_scan: Failed to identify ${recname}"
        $scriptpath/adb-sendkey.sh SLEEP
        adb disconnect $ANDROID_DEVICE
        unlocktuner
        continue
    fi
    # We have the video device,now get the audio device
    $scriptpath/adb-sendkey.sh SLEEP
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
    assigned="$assigned $VIDEO_IN"
    echo `$LOGDATE` Successfully created parameters in $DATADIR/${recname}.conf.
    unlocktuner
done
if [[ "$ISMYTHBACKEND" == "" ]] ; then
    ISMYTHBACKEND=1
fi
# When running as a service, start up the leancap_ready processes
if (( ! isterminal && ISMYTHBACKEND )) ; then
    for conffile in /etc/opt/mythtv/$reqname.conf ; do
        recname=$(basename $conffile .conf)
        numlines=$(wc -l < $DATADIR/${recname}.conf)
        if (( numlines > 0 )) ; then
            # script that runs forever to keep device in a ready state
            let capseq++
            $scriptpath/leancap_ready.sh $recname $capseq &
            pidlist="$pidlist $!"
        fi
    done
fi

$LOGDATE > $LOCKBASEDIR/scandate

if [[ "$pidlist" != "" ]] ; then
    # wait for ready processes to end
    wait
fi
