#!/bin/bash

# External Recorder Tuner
# Parameter 1 - recorder name e.g. leancap1
# Parameter 2 - channel number
# Parameter 3 - LOCK, NOLOCK, NOPLAY. default is LOCK. NOPLAY implies LOCK

recname=$1
channum=$2
lockreq=$3

if [[ "$recname" == "" || "$channum" == "" ]] ; then
    echo `$LOGDATE` "$0 Invalid Request."
    exit 99
fi

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/leanfuncs.sh

initialize

getparms

echo `$LOGDATE` "Request to tune channel $channum "

# tunestatus values
# idle
# tuned

if [[ "$lockreq" != NOLOCK ]] ; then
    # if locked for chanlist, kill the chanlist
    if ! locktuner ; then
        command=$(ps h -q $lockpid -o command)
        if [[ "$command" == *leancap_chanlist.sh* ]] ; then
            echo `$LOGDATE` "Killing leancap_chanlist.sh to tune channel"
            kill $lockpid
        fi
    fi
    if ! locktuner 120 ; then
        echo `$LOGDATE` "Encoder $recname is locked, exiting"
        exit 2
    fi
    gettunestatus
    if [[ "$tunestatus" == tuned  ]] ; then
        if [[ "$tunechan" == "$channum" ]] ; then
            echo `$LOGDATE` "Tuner already tuned, all ok"
            exit 0
        else
            echo `$LOGDATE` "WARNING tuner already tuned to $tunechan, will retune"
            adb connect $ANDROID_DEVICE
            capturepage
            if [[ "${pagename,,}" != "$NAVTYPELC" ]] ; then
                $scriptpath/adb-sendkey.sh BACK
                sleep 3
            fi
        fi
    fi
fi

tuned=N
if (( channum <= 0 )) ; then
    echo `$LOGDATE` "ERROR Invalid channel number: $channum"
    exit 2
fi

tunefile=$TEMPDIR/${recname}_tune.stat
true > $tunefile

adb connect $ANDROID_DEVICE

chanlistfile=$DATADIR/"$NAVTYPE".txt
if [[ -f "$chanlistfile" ]] ; then
    chanlist=($(cat "$chanlistfile"))
else
    echo `$LOGDATE` "WARNING No channel list file found. Run leancap_chanlist.sh"
fi

chansearch $channum
ixchannum=$chanindex

if (( channum != ${chanlist[chanindex]} )) ; then
    echo `$LOGDATE` "WARNING: Required channel: $channum not in $chanlistfile"
    $scriptpath/notify.py "WARNING: Required Channel not in file" \
        "leancap_tune: Required channel: $channum not in $chanlistfile on recorder: $recname" &
fi

for (( xx=0; xx<5; xx++ )) ; do
    if [[ "$tuned" == Y ]] ; then  break; fi

    navigate "$NAVTYPE" "$NAVKEYS"
    currchan=0
    direction=N
    errorpassed=0
    jumpsize=100
    trycount=0
    chansnotified=0
    extrachans=

    while (( currchan != channum )) ; do
        if (( currchan == 0 )) ; then
            # get out of the Filter box
            $scriptpath/adb-sendkey.sh DOWN DOWN DOWN
        fi
        # To test incorrect selection condition:
        #~ $scriptpath/adb-sendkey.sh RIGHT
        getchannellist
        echo `$LOGDATE` "channels: ${channels[@]}"
        if (( arrsize != 5 )) ; then
            echo `$LOGDATE` "Wrong number of channels, trying again"
            $scriptpath/adb-sendkey.sh MENU
            $scriptpath/adb-sendkey.sh LEFT
            $scriptpath/adb-sendkey.sh RIGHT
            continue 2
        fi
        getchannelselection
        if (( selection < 0)) ; then
            cp $TEMPDIR/${recname}_capture.png $TEMPDIR/${recname}_capture_channels.png
        fi
        for (( xx2=0; selection<0 && xx2<5; xx2++ )) ; do
            echo `$LOGDATE` "No channel selection, moving cursor"
            # Move cursor left in case a program is selected instead of a channel
            $scriptpath/adb-sendkey.sh LEFT
            capturepage
            if [[ "${pagename,,}" == "$NAVTYPELC" ]] ; then
                getchannellist
                getchannelselection
            else
                break
            fi
        done
        if (( selection < 0)) ; then
            echo `$LOGDATE` "ERROR: Cannot determine channel selection, try again"
            savefile=$DATADIR/$($LOGDATE)_${recname}_capture_channels.png
            cp $TEMPDIR/${recname}_capture_channels.png "$savefile"
            echo `$LOGDATE` "$savefile created for debugging"
            launchXfinity
            #~ $scriptpath/adb-sendkey.sh MENU
            #~ $scriptpath/adb-sendkey.sh LEFT
            #~ $scriptpath/adb-sendkey.sh RIGHT
            continue 2
        fi
        repairchannellist
        currchan=${channels[selection]}
        echo `$LOGDATE` "Current channel: $currchan"
        if (( channum == currchan )) ; then
            tuned=Y
            break
        fi
        chansearch $currchan
        # channum : desired channel
        # currchan : currently selected channel
        # ixchannum = index of desired channel
        # chanindex : index of currently selected channel
        #    or channel below that if selected channel not in list
        if (( currchan != ${chanlist[chanindex]} )) ; then
            echo `$LOGDATE` "WARNING: Extra channels: $currchan not in $chanlistfile"
            extrachans="$extrachans $currchan"
            if (( ++chansnotified == 5 )) ; then
                $scriptpath/notify.py "WARNING: Extra channels in file" \
                    "leancap_tune: Extra channels: $extrachans not in $chanlistfile on recorder: $recname" &
            fi
        fi

        let distance=ixchannum-chanindex
        # Is the channel on the page?
        isonpage=0
        for (( xy=0; xy<arrsize; xy++ )) ; do
            if (( channum == channels[xy] )) ; then
                let distance=xy-selection
                isonpage=1
                break
            fi
        done
        # currchan 0 indicates we have wandered into the Unnumbered
        # tv-go channels at the end, so go up.
        if (( currchan == 0 )) ; then
            distance=-100
        fi
        if (( distance < 0 )) ; then
            direction=UP
            let distance=-distance
        else
            direction=DOWN
        fi
        if (( distance < jumpsize )) ; then
            jumpsize=$distance
        fi
        if [[ "$prior_direction" == "" ]] ; then
            prior_direction=$direction
        fi
        if [[ $isonpage == 0 && $prior_direction != $direction ]] ; then
            if (( jumpsize <= 1 )) ; then
                let trycount++
                if (( trycount > 3 )) ; then
                    echo `$LOGDATE` "ERROR: Cannot find channel $channum."
                    tuned=N
                    break 2
                fi
            else
                trycount=0
            fi
            # Each time we reverse direction halve the number of
            # channels jumped
            let jumpsize=jumpsize/2
        fi
        if (( jumpsize < 1 )) ; then
            jumpsize=1
        fi
        prior_direction=$direction
        keypress=
        for (( xy=0; xy<jumpsize; xy++ )) ; do
            keypress="$keypress $direction"
        done
        $scriptpath/adb-sendkey.sh $keypress
    done
done

if [[ "$tuned" == Y ]] ; then
    echo "tunetime=$(date +%s)" > $tunefile
    echo "tunechan=$channum" >> $tunefile
    echo "tunestatus=tuned" >> $tunefile
    echo `$LOGDATE` "Complete tuning channel: $channum on recorder: $recname"
    # Start playback
    if [[ "$lockreq" != NOPLAY ]] ; then
        # pause 1 second because sometimes this may be too quick
        # to register
        sleep 1
        $scriptpath/adb-sendkey.sh DPAD_CENTER
    fi
    rc=0
else
    true > $tunefile
    echo `$LOGDATE` "ERROR: Unable to tune channel: $channum on recorder: $recname"
    $scriptpath/notify.py "Unable to Tune" \
        "leancap_tune: Unable to tune channel: $channum on recorder: $recname" &
    rc=2
fi
exit $rc
