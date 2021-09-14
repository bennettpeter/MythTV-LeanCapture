#!/bin/bash

# Create channel list
# This uses the "All Channels" or "Favorite Channels" part of xfinity stream.
# There is only one list - it can be used by all recorders
# Create file $DATADIR/All Channels.txt or $DATADIR/Favorite Channels.txt
# Parameter 1 - recorder name, defaults to leancap1

recname="$1"
if [[ "$recname" == "" ]] ; then
    recname=leancap1
fi

. /etc/opt/mythtv/leancapture.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/leanfuncs.sh

initialize

getparms

if ! locktuner 10 ; then
    echo `$LOGDATE` "Encoder $recname is locked, exiting"
    exit 2
fi
gettunestatus
if [[ "$tunestatus" != idle  ]] ; then
    echo `$LOGDATE` "ERROR: Tuner in use. Status $tunestatus"
    exit 5
fi

adb connect $ANDROID_DEVICE

# Get to channel list
navigate "$NAVTYPE" "$NAVKEYS"

# 50 UP presses
keypress=
for (( xy=0; xy<50; xy++ )) ; do
    keypress="$keypress UP"
done

# Escape from filter box
sleep 5
$scriptpath/adb-sendkey.sh DOWN DOWN DOWN

# Get to top of list
for (( ; ; )) ; do
    $scriptpath/adb-sendkey.sh $keypress
    getchannellist
    echo "Channels: ${channels[@]}"
    if [[ "$priorchannels" == "${channels[@]}" ]] ; then break ; fi
    priorchannels="${channels[@]}"
done

chanlistfile=$DATADIR/"$NAVTYPE".txt
chanlistfilegen=$DATADIR/"$NAVTYPE"_gen.txt
newchanlistfilegen=$DATADIR/"$NAVTYPE"_new_gen.txt
errfile=$DATADIR/"$NAVTYPE"_errors.txt
true > "$newchanlistfilegen"
true > "$errfile"

currchan=0
numseqerrors=0
numerrors=0
fileseq=0

for (( ; ; )) ; do
    echo `$LOGDATE` "Channels: ${channels[@]} arrsize: $arrsize"
    valid=-1
    msg=()
    for (( ix=0 ; ix<arrsize ; ix++ )) ; do
        err=0
        priorchan=$currchan
        currchan=${channels[ix]}
        if [[ "$currchan" == *_* ]] ; then
            echo `$LOGDATE` "ERROR - invalid channel $currchan"
            err=1
        elif (( currchan < priorchan )) ; then
            echo `$LOGDATE` "WARNING out of sequence, channel $currchan is after $priorchan"
            err=1
        fi
        if (( err )) ; then
            let num=fileseq+ix+1
            let numseqerrors++
            if (( numseqerrors <= 1 )) ; then
                let fix=priorchan+1
                echo "Changing  $currchan to $fix"
                channels[ix]="$fix"
                msg[ix]="Line $num $currchan changed to $fix"
                currchan="$fix"
            fi
        else
            valid=$ix
            numseqerrors=0
        fi
    done

    # If we are due to end, only output the valid entries of the last screen
    if (( numseqerrors > 1 )) ; then
        let last=valid+1
    else
        last=$arrsize
    fi

    for (( ix=0 ; ix<last ; ix++ )) ; do
        if (( ${channels[ix]} > MAXCHANNUM )) ; then
            break 2
        fi
        echo "${channels[ix]}" >> "$newchanlistfilegen"
        if [[ "${msg[ix]}" != "" ]] ; then
            echo "${msg[ix]}" >> "$errfile"
            let numerrors++
        fi
        let fileseq++
    done
    if (( numseqerrors > 1 )) ; then
        echo `$LOGDATE` "More than 1 sequential error - assume end of list"
        break
    fi

    getchannelselection
    let distance=3-selection+5
    keypress=
    for (( xy=0; xy<distance; xy++ )) ; do
        keypress="$keypress DOWN"
    done
    $scriptpath/adb-sendkey.sh $keypress
    getchannellist
    if [[ "$priorchannels" == "${channels[@]}" ]] ; then break ; fi
    priorchannels="${channels[@]}"
done

if [[ -f "$chanlistfilegen" ]] ; then
    if diff "$newchanlistfilegen" "$chanlistfilegen" ; then
        echo `$LOGDATE` "Channel list same as before. No problems."
        exit 0
    fi
fi
cp "$newchanlistfilegen" "$chanlistfilegen"
# if chanlistfile does not exist copy it regardless of errors
cp -n "$chanlistfilegen" "$chanlistfile"
if (( numerrors == 0 )) ; then
    cp "$chanlistfilegen" "$chanlistfile"
else
    echo `$LOGDATE` "Number of errors: $numerrors. Errors listed below. See $errfile"
    $scriptpath/notify.py "Channel list needs fixing" \
        "leancap_chanlist: New list has errors." &
    echo `$LOGDATE` "cp $chanlistfilegen $chanlistfile then fix the errors there."
fi

cat "$errfile"
