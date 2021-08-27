#!/bin/bash

# External Recorder Tuner
# This uses the "All Channels" part of xfinity stream, so it
# can record from any channel in your lineup
# Parameter 1 - recorder name
# Parameter 2 - channel number
# Parameter 3 - LOCK or NOLOCK, default is LOCK

recname=$1
channum=$2
lockreq=$3
if [[ "$lockreq" != NOLOCK ]] ; then
    lockreq=LOCK
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

if [[ "$lockreq" == LOCK ]] ; then
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
            if [[ "$pagename" != "$NAVTYPE" ]] ; then
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

tunefile=$DATADIR/${recname}_tune.stat
true > $tunefile

adb connect $ANDROID_DEVICE

leanchans=($(cat /etc/opt/mythtv/leanchans.txt))
for (( xx=0; xx<5; xx++ )) ; do
    if [[ "$tuned" == Y ]] ; then  break; fi

    navigate "$NAVTYPE" "$NAVKEYS"
    ##favorites - channel numbers##
    currchan=0
    direction=N
    errorpassed=0
    jumpsize=50
    trycount=0
    while (( currchan != channum )) ; do
        # Note this assumes a 1280-x720 resolution
        CROP="-crop 86x600+208+120"
        TESSPARM="-c tessedit_char_whitelist=0123456789"
        capturepage
        onscreen=$(cat $DATADIR/${recname}_capture_crop.txt)
        # In case nothing found yet
        channels=($onscreen)
        arrsize=${#channels[@]}
        if (( arrsize != 5 )) ; then
            channels=($(gocr -C 0-9 -l 200 $DATADIR/${recname}_capture_crop.png))
            arrsize=${#channels[@]}
        fi
        if (( arrsize != 5 )) ; then
            echo `$LOGDATE` "Wrong number of channels, trying again"
            $scriptpath/adb-sendkey.sh MENU
            $scriptpath/adb-sendkey.sh LEFT
            $scriptpath/adb-sendkey.sh RIGHT
            continue 2
        fi
        echo `$LOGDATE` "channels: ${channels[@]}"

        topchan=${channels[0]}
        prior_currchan=$currchan
        if (( currchan == 0 )) ; then
            $scriptpath/adb-sendkey.sh DOWN DOWN DOWN
            CROP="-crop 86x600+208+120"
            TESSPARM="-c tessedit_char_whitelist=0123456789"
            capturepage
        fi
        getchannelselection
        if (( selection == -1 )) ; then
            echo `$LOGDATE` "ERROR: Cannot determine channel selection, trying again"
            $scriptpath/adb-sendkey.sh MENU
            $scriptpath/adb-sendkey.sh LEFT
            $scriptpath/adb-sendkey.sh RIGHT
            continue 2
        fi
        currchan=${channels[selection]}
        # Check for out of sequence caused by OCR error
        if (( selection > 0 && currchan < channels[selection-1] )) ; then
            # Set to next possible number. This will either be the actual
            # channel selected if numbers are sequential at this point,
            # or else an invalid number in the correct sequence.
            let currchan=channels[selection-1]+1
        fi
        echo `$LOGDATE` "Current channel: $currchan"
        let distance=channum-currchan
        if (( distance == 0 )) ; then
            tuned=Y
            break
        fi
        # Is the channel on the page?
        isonpage=0
        for (( xy=0; xy<arrsize; xy++ )) ; do
            if (( channum == channels[xy] )) ; then
                let distance=xy-selection
                isonpage=1
                break
            fi
        done
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
    $scriptpath/adb-sendkey.sh DPAD_CENTER
    rc=0
else
    true > $tunefile
    echo `$LOGDATE` "ERROR: Unable to tune channel: $channum on recorder: $recname"
    $scriptpath/notify.py "Unable to Tune" \
        "leancap_tune: Unable to tune channel: $channum on recorder: $recname" &
    rc=2
fi
exit $rc
