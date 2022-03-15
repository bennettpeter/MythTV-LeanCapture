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
    capturepage
    if [[ `stat -c %s $DATADIR/${recname}_capture_crop.txt` == 0 ]] ; then
        $scriptpath/adb-sendkey.sh POWER
    fi
    $scriptpath/adb-sendkey.sh HOME
    $scriptpath/adb-sendkey.sh DPAD_CENTER
    adb disconnect $ANDROID_DEVICE
done

capseq=0
pidlist=
assigned=
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
    prodmodel=$(adb -s $ANDROID_DEVICE shell getprop ro.product.model)
    case $prodmodel in
        AFT*)
            echo fire stick
            $scriptpath/adb-sendkey.sh HOME
            $scriptpath/adb-sendkey.sh LEFT
            $scriptpath/adb-sendkey.sh LEFT
            $scriptpath/adb-sendkey.sh DOWN
            ;;
        *)
            echo other android
            $scriptpath/adb-sendkey.sh HOME
            $scriptpath/adb-sendkey.sh SETTINGS
            ;;
    esac
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
            case $prodmodel in
                AFT*)
                    if grep "Controllers & Bluetooth" $DATADIR/${recname}_capture_crop.txt ; then
                        match=Y
                        break
                    elif [[ "$pagename" == "We"*"detect your remote" ]] ; then
                        # We don't know if this message comes from the device
                        # currently processing, so send the enter once and start over
                        if [[ "$remotefix" != *"$VIDEO_IN"* ]] ; then
                            # HOME in case this is not the one
                            $scriptpath/adb-sendkey.sh HOME
                            # DPAD_CENTER in case this is the one
                            $scriptpath/adb-sendkey.sh DPAD_CENTER
                            # HOME so we can start over
                            $scriptpath/adb-sendkey.sh HOME
                            $scriptpath/adb-sendkey.sh LEFT
                            $scriptpath/adb-sendkey.sh LEFT
                            $scriptpath/adb-sendkey.sh DOWN
                            sleep 2
                            remotefix="$remotefix $VIDEO_IN"
                            trynum=0
                        fi
                    fi
                    ;;
                *)
                    if grep "Remotes & Accessories" $DATADIR/${recname}_capture_crop.txt ; then
                        match=Y
                        break
                    fi
                    ;;
            esac
            sleep 1
        done
        if [[ $match == Y ]] ; then break ; fi
        echo `$LOGDATE` "Failed to read screen on ${recname}, trying again"
        sleep 1
    done

    if [[ $match != Y ]] ; then
        echo `$LOGDATE` "Failed to navigate on ${recname} - see $DATADIR/${recname}_capture.png"
        $scriptpath/notify.py "Fire Stick Problem" \
          "leancap_scan: Failed to navigate on ${recname}" &
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
