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

numdate=`date "+%Y%m%d_%H%M%S"`
source $scriptpath/leanfuncs.sh
initialize
getparms

if ! locktuner 60 ; then
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
    keypress="$keypress UP +3 UNKNOWN"
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
errfile=$DATADIR/"$NAVTYPE"_errors.txt
fixupfile=$DATADIR/"$NAVTYPE"_fixups.txt
true > "$chanlistfilegen"
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
        fi
        if (( err || currchan < priorchan )) ; then
            echo `$LOGDATE` "WARNING out of sequence, channel $priorchan is before $currchan"
            fixup=($(grep "^$priorchan $currchan" "$fixupfile"))
            if [[ ${fixup[2]} != "" ]] ; then
                fix="${fixup[2]}"
                echo "Fixups: Changing  $currchan to $fix"
                channels[ix]="$fix"
                currchan="$fix"
                err=0
            else
                err=1
            fi
        fi
        if (( err )) ; then
            let num=fileseq+ix+1
            let numseqerrors++
            if (( numseqerrors <= 1 )) ; then
                let fix=priorchan+1
                echo "Changing  $currchan to $fix"
                channels[ix]="$fix"
                msg[ix]="error: Line $num $currchan changed to $fix"
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
        echo "${channels[ix]}" >> "$chanlistfilegen"
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
        keypress="$keypress DOWN +3 UNKNOWN"
    done
    $scriptpath/adb-sendkey.sh $keypress
    getchannellist
    if [[ "$priorchannels" == "${channels[@]}" ]] ; then break ; fi
    priorchannels="${channels[@]}"
done

echo "Channel Changes < means removed > means added:"
if diff "$chanlistfile" "$chanlistfilegen" ; then
    echo `$LOGDATE` "Channel list same as before. No problems."
    exit 0
fi
# Copy here only if there is no old file
cp -n "$chanlistfilegen" "$chanlistfile"
cp "$chanlistfilegen" $DATADIR/"${numdate}_$NAVTYPE".txt
oldnumchans=$(wc -l < "$chanlistfile")
newnumchans=$(wc -l < "$chanlistfilegen")
if (( newnumchans - oldnumchans < -10 )) ; then
    $scriptpath/notify.py "Channel list lost more than 5" \
        "leancap_chanlist: See new list in $numdate_$chanlistfilegen .
cp $chanlistfilegen $chanlistfile if this is ok, otherwise rerun leancap_chanlist."
    exit
fi
if (( numerrors == 0 )) ; then
    cp "$chanlistfilegen" "$chanlistfile"
    $scriptpath/notify.py "Channel list changes" \
        "leancap_chanlist: See new list in $numdate_$chanlistfilegen .
Run $scriptpath/update_sd_channels.sh to keep schedules direct in sync"
else
    echo `$LOGDATE` "Number of errors: $numerrors. Errors listed below. See $errfile"
    $scriptpath/notify.py "Channel list needs fixing" \
        "leancap_chanlist: New list has errors. See $logfile"
    echo `$LOGDATE` "cp $chanlistfilegen $chanlistfile then fix the errors there."
    echo "Add a line with priorchannel, currentchannel, fixcurrentchannel to $fixupfile"
fi

cat "$errfile"
