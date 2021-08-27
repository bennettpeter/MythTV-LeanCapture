#!/usr/bin/echo This file is not executable
# Common functions used by lean capture scripts
# This file need not be marked executable

LOGDATE='date +%Y-%m-%d_%H-%M-%S'
OCR_RESOLUTION=1280x720
updatetunetime=0
ADB_ENDKEY=
LOCKBASEDIR=/run/lock/leancap
# Keys : 6 DOWNS for favorite or 5 DOWNS for All
case "$NAVTYPE" in
    "Favorite Channels")
        NAVKEYS="DOWN DOWN DOWN DOWN DOWN DOWN"
        ;;
    "All Channels")
        NAVKEYS="DOWN DOWN DOWN DOWN DOWN"
        ;;
    *)
        NAVTYPE="All Channels"
        NAVKEYS="DOWN DOWN DOWN DOWN DOWN"
        ;;
esac


function exitfunc {
    local rc=$?
    echo `$LOGDATE` "Exit" >> $logfile
    if [[ "$ADB_ENDKEY" != "" && "$ANDROID_DEVICE" != "" && istunerlocked ]] ; then
        $scriptpath/adb-sendkey.sh $ADB_ENDKEY >> $logfile
    fi
    if [[ "$ffmpeg_pid" != "" ]] && ps -q $ffmpeg_pid >/dev/null ; then
        kill $ffmpeg_pid
    fi
    if [[ "$tail_pid" != "" ]] && ps -q $tail_pid >/dev/null ; then
        kill $tail_pid
    fi
    if istunerlocked ; then
        if (( updatetunetime )) ; then
            echo "tunetime=$(date +%s)" >> $tunefile
        fi
        if [[ "$ANDROID_DEVICE" != "" ]] ; then
            adb disconnect $ANDROID_DEVICE >> $logfile
        fi
        unlocktuner
    fi
}

# before calling this recname must be set
# Param 1 = number of extra attempts (1 sec each)
# 0 or blank = 1 attempt
function locktuner {
    if [[ "$recname" == "" ]] ; then return 1 ; fi
    attempts=$1
    mkdir -p $LOCKBASEDIR
    if [[ ! -w  $LOCKBASEDIR ]] ; then
        echo `$LOGDATE` "ERROR: $LOCKBASEDIR is not writable"
        exit 2
    fi
    touch $LOCKBASEDIR/$recname.pid
    while (( attempts-- >= 0 )) ; do
        if ln $LOCKBASEDIR/$recname.pid $LOCKBASEDIR/$recname.lock 2>/dev/null ; then
            # We have the lock - store the pid
            echo $$ > $LOCKBASEDIR/$recname.pid
            return 0
        else
            pid=$(cat $LOCKBASEDIR/${recname}.lock)
            # If the lock is already ours then return success
            if [[ "$pid" == $$ ]] ; then return 0 ; fi
            # If lock expired, remove it and try again
            if [[ "$pid" == "" ]] || ! ps -q "$pid" >/dev/null ; then
                rm $LOCKBASEDIR/$recname.lock
                let attempts++
            else
                if (( attempts%5 == 0 )) ; then
                    echo `$LOGDATE` "Waiting for lock on $recname"
                fi
                if (( attempts >= 0 )) ; then
                    sleep 1
                fi
            fi
        fi
    done
    return 1
}

# check if locked by us
function istunerlocked {
    if [[ "$recname" == "" ]] ; then return 1 ; fi
    pid=$(cat $LOCKBASEDIR/${recname}.lock 2>/dev/null)
    # If we locked it ourselves return true
    if [[ "$pid" == $$ ]] ; then return 0 ; fi
    return 1
}

function unlocktuner {
    if [[ "$recname" == "" ]] ; then return 1 ; fi
    pid=$(cat $LOCKBASEDIR/${recname}.lock 2>/dev/null)
    if [[ "$pid" == $$ ]] ; then
        # remove lock
        rm $LOCKBASEDIR/$recname.lock
    fi
}

# param NOREDIRECT to prevent redirection of stdout and stderr
function initialize {
    if [[ -t 1 ]] ; then
        isterminal=1
    else
        isterminal=0
    fi
    tail_pid=
    REDIRECT=N
    if [[ "$recname" == "" ]] ; then
        logfile=$LOGDIR/${scriptname}.log
    else
        logfile=$LOGDIR/${scriptname}_${recname}.log
    fi
    if [[ "$1" != NOREDIRECT ]] ; then
        REDIRECT=Y
        exec 1>>$logfile
        exec 2>&1
        if (( isterminal )) ; then
            tail -f $logfile >/dev/tty &
            tail_pid=$!
        fi
    fi
    echo `$LOGDATE` "Start of run ***********************"
    trap exitfunc EXIT
    if [[ "$recname" != "" ]] ; then
        true > $DATADIR/${recname}_capture_crop.txt
    fi
}

# Parameter 1 - set to PRIMARY to return with code 2 if primary device
# (ethernet) is not available.
# Return code 1 for fallback, 2 for error, 3 for not set up
function getparms {
    # Select the [default] section of conf and put it in a file
    # to source it
    ANDROID_MAIN=
    ANDROID_DEVICE=
    awk '/^\[default\]$/ { def = 1; next }
    /^\[/ { def = 0; next }
    def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
    > $DATADIR/etc_${recname}.conf
    . $DATADIR/etc_${recname}.conf
    # This sets VIDEO_IN and AUDIO_IN
    . $DATADIR/${recname}.conf
    if [[ "$ANDROID_MAIN" == "" ]] ; then
        errormsg="$recname not set up"
        echo `$LOGDATE` "ERROR: $errormsg"
        return 3
    fi
    errormsg=
    ANDROID_DEVICE=$ANDROID_MAIN
    ping -c 1 $ANDROID_MAIN >/dev/null
    local rc=$?
    if (( rc == 2 )) ; then
        # network unavailable - wait and try again. This can happen
        # if we just resumed from suspend
        sleep 10
        ping -c 1 $ANDROID_MAIN >/dev/null
        rc=$?
    fi
    if (( rc > 0 )) ; then
        if [[ "$ANDROID_FALLBACK" == "" ]] ; then
            errormsg="Primary network failure and no fallback"
            echo `$LOGDATE` "ERROR: $errormsg"
            return 2
        elif [[ "$1" == "PRIMARY" ]] ; then
            errormsg="Primary network failure"
            echo `$LOGDATE` "ERROR: $errormsg"
            return 2
        elif ping -c 1 $ANDROID_FALLBACK >/dev/null ; then
            errormsg="Using fallback network adapter"
            echo `$LOGDATE` "WARNING: $errormsg"
            ANDROID_DEVICE=$ANDROID_FALLBACK
            return 1
        else
            errormsg="Primary and secondary network failure"
            echo `$LOGDATE` "ERROR: $errormsg"
            return 2
        fi
    fi
    export ANDROID_DEVICE
    return 0
}

# Parameter 1 - set to video to only allow capture from /dev/video.
# Set to adb to only allow adb. Blank to try video first then adb
# VIDEO_IN - set to blank will prevent capture from /dev/video
# TESSPARM - set to "-c tessedit_char_whitelist=0123456789" to restrict to numerics
# CROP - crop parameter (default -gravity East -crop 95%x100%)
# Return 1 if wrong resolution is found
function capturepage {
    pagename=
    imagesize=0
    local source_req=$1
    local rc=0
    if [[ "$CROP" == "" ]] ; then
        CROP="-gravity East -crop 95%x100%"
    fi
    #~ if [[ "$TESSPARM" == "" ]] ; then
        #~ TESSPARM="-c tessedit_char_whitelist=0123456789QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm "
    #~ fi
    cp -f $DATADIR/${recname}_capture_crop.txt $DATADIR/${recname}_capture_crop_prior.txt
    true > $DATADIR/${recname}_capture.png
    true > $DATADIR/${recname}_capture_crop.png
    true > $DATADIR/${recname}_capture_crop.txt
    cap_source=
    if ( [[ "$source_req" == "" || "$source_req" == video  ]] ) \
      && ( [[ "$ffmpeg_pid" == "" ]] || ! ps -q $ffmpeg_pid >/dev/null ) \
      && [[ "$VIDEO_IN" != "" ]] ; then
        ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s $OCR_RESOLUTION -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.png
        cap_source=ffmpeg
    fi
    imagesize=$(stat -c %s $DATADIR/${recname}_capture.png)
    if (( imagesize == 0 )) ; then
        if [[ "$source_req" == "" || "$source_req" == adb  ]] ; then
            adb -s $ANDROID_DEVICE exec-out screencap -p > $DATADIR/${recname}_capture.png
            cap_source=adb
            imagesize=$(stat -c %s $DATADIR/${recname}_capture.png)
        fi
    fi
    if (( imagesize > 0 )) ; then
        resolution=$(identify -format %wx%h $DATADIR/${recname}_capture.png)
        if [[ "$resolution" != "$OCR_RESOLUTION" ]] ; then
            rc=1
            echo `$LOGDATE` "WARNING Incorrect resolution $resolution"
            convert $DATADIR/${recname}_capture.png -resize "$OCR_RESOLUTION" $DATADIR/${recname}_capturex.png
            cp -f $DATADIR/${recname}_capturex.png $DATADIR/${recname}_capture.png
            imagesize=$(stat -c %s $DATADIR/${recname}_capture.png)
        fi
    fi
    if (( imagesize > 0 )) ; then
        convert $DATADIR/${recname}_capture.png $CROP -negate -brightness-contrast 0x20 $DATADIR/${recname}_capture_crop.png
    fi
    if [[ `stat -c %s $DATADIR/${recname}_capture_crop.png` != 0 ]] ; then
        tesseract -c page_separator="" $DATADIR/${recname}_capture_crop.png  - $TESSPARM 2>/dev/null | sed '/^ *$/d' > $DATADIR/${recname}_capture_crop.txt
        if [[ `stat -c %s $DATADIR/${recname}_capture_crop.txt` == 0 ]] ; then
            echo `$LOGDATE` Blank Screen from $cap_source
        elif diff -q $DATADIR/${recname}_capture_crop.txt $DATADIR/${recname}_capture_crop_prior.txt >/dev/null ; then
            echo `$LOGDATE` Same Screen Again
        else
            echo "*****" `$LOGDATE` Screen from $cap_source
            cat $DATADIR/${recname}_capture_crop.txt
            echo "*****"
        fi
        pagename=$(head -n 1 $DATADIR/${recname}_capture_crop.txt)
    else
        echo `$LOGDATE` No Screen capture
    fi
    TESSPARM=
    CROP=
    return $rc
}

function waitforpage {
    wanted="$1"
    local xx=0
    while [[ "$pagename" != "$wanted" ]] && (( xx++ < 90 )) ; do
        capturepage
        if [[ "$pagename" == "We"*"detect your remote" ]] ; then
            $scriptpath/adb-sendkey.sh DPAD_CENTER
        fi
        sleep 0.5
    done
    if [[ "$pagename" != "$wanted" ]] ; then
        echo `$LOGDATE` "ERROR - Cannot get to $wanted Page"
        return 2
    fi
    echo `$LOGDATE` "Reached $wanted page"
    return 0
}

# tunestatus values
# idle (default if blank)
# tuned
#
# If playing the tuner is locked

function gettunestatus {
    if ! locktuner ; then
        echo `$LOGDATE` "ERROR - Cannot lock to get tune status"
        return 1
    fi
    tunefile=$DATADIR/${recname}_tune.stat
    touch $tunefile
    # Default tunestatus
    tunestatus=idle
    tunetime=0
    source $tunefile
    now=$(date +%s)

    # Tuned more than 5 minutes ago and not playing - reset tunestatus
    if (( tunetime < now-300 )) && [[ "$tunestatus" == tuned ]] ; then
        echo `$LOGDATE` Tuner $recname expired, resetting
        tunestatus=idle
        true > $tunefile
    fi
    return 0
}

function launchXfinity {
    adb -s $ANDROID_DEVICE shell am force-stop com.xfinity.cloudtvr.tenfoot
    sleep 1
    adb -s $ANDROID_DEVICE shell am start -n com.xfinity.cloudtvr.tenfoot/com.xfinity.common.view.LaunchActivity
}

# Navigate to a desired page
# params
# 1 Desired page name, e.g. "Favorite Channels"
# 2 Keystrokes in menu
#   favorites:  "DOWN DOWN DOWN DOWN DOWN DOWN"
#   All channels: "DOWN DOWN DOWN DOWN DOWN"
#   recordings: "DOWN"
# e.g. navigate "Favorite Channels" "DOWN DOWN DOWN DOWN DOWN DOWN"
#      navigate Recordings "DOWN"
function navigate {
    local pagereq="$1"
    local keystrokes="$2"
    local unknowns=0
    local blanks=0
    local xx=0
    local expect=0
    # Normal would be 5 or 6 iterations to get to favorites
    for (( xx=0 ; xx < 25 ; xx++ )) ; do
        sleep 0.5
        capturepage
        case "$pagename" in
        "")
            # If sleeping need to send POWER to turn it back on
            if (( xx == 0 || ++blanks > 4 )) ; then
                $scriptpath/adb-sendkey.sh POWER
                $scriptpath/adb-sendkey.sh HOME
                sleep 0.5
                launchXfinity
                blanks=0
            fi
            ;;
        "We"*"detect your remote")
            $scriptpath/adb-sendkey.sh DPAD_CENTER
            ;;
        "xfinity stream")
            continue
            ;;
        "For You")
            sleep 0.5
            # LEFT invokes the menu in case MENU dismissed it
            $scriptpath/adb-sendkey.sh MENU
            $scriptpath/adb-sendkey.sh LEFT
            $scriptpath/adb-sendkey.sh UP UP UP UP UP UP UP UP UP UP UP UP UP UP UP UP UP DOWN
            if [[ "$keystrokes" != "" ]] ; then
                $scriptpath/adb-sendkey.sh $keystrokes
            fi
            # Check if the correct menu item is selected
            local xy=0
            for (( xy=0 ; xy < 25 ; xy++ )) ; do
                capturepage
                getmenuselection
                if [[ "$selection" == "" || "${menuitems[selection]}" == "$pagereq" ]] ; then
                    $scriptpath/adb-sendkey.sh DPAD_CENTER
                    let expect++
                    break
                else
                    echo `$LOGDATE` "Wrong item selected, wanted $pagereq got ${menuitems[$selection]}"
                    local xx2
                    local entries=${#menuitems[@]}
                    local wanted=
                    for (( xx2=0; xx2<entries ; xx2++ )) ; do
                        if [[ "${menuitems[xx2]}" == "$pagereq" ]] ; then
                            wanted=xx2
                            break
                        fi
                    done
                    if [[ "$wanted" == "" ]] || (( wanted == selection )) ; then
                        echo `$LOGDATE` "Cannot find correct menu item, try again"
                        sleep 1
                        # LEFT invokes the menu again if MENU dismissed it
                        $scriptpath/adb-sendkey.sh MENU
                        $scriptpath/adb-sendkey.sh LEFT
                        $scriptpath/adb-sendkey.sh UP UP UP UP UP UP UP UP UP UP UP UP UP UP UP UP UP DOWN
                        if [[ "$keystrokes" != "" ]] ; then
                            $scriptpath/adb-sendkey.sh $keystrokes
                        fi
                    else
                        if (( wanted > selection )) ; then
                            $scriptpath/adb-sendkey.sh DOWN
                        else
                            $scriptpath/adb-sendkey.sh UP
                        fi
                    fi
                fi
            done
            if (( xy == 25 )) ; then
                # failed to get to menu item - back out of menu
                echo `$LOGDATE` "Cannot find correct menu item after many tries, go back"
                $scriptpath/adb-sendkey.sh BACK
            fi
            ;;
        "$pagereq")
            break
            ;;
        *)
            if (( expect == 1 )) ; then
                let expect++
                # landed on wrong page - back and try again once only
                $scriptpath/adb-sendkey.sh BACK
            elif (( ++unknowns > 2 )) ;then
                launchXfinity
                unknowns=0
            fi
            ;;
        esac
    done
    if [[ "$pagename" != "$pagereq" ]] ; then
        echo `$LOGDATE` "ERROR: Unable to reach $pagereq: $recname."
        return 3
    fi
    return 0
}

# Get channel selection. Must be preceded by capturepage to capture the menu.
# Return:
# selection - index of selected item or blank if error

function getchannelselection {
    convert $DATADIR/${recname}_capture_crop.png $DATADIR/${recname}_capture_crop.jpg
    jp2a --width=10  -i $DATADIR/${recname}_capture_crop.jpg \
      | sed 's/ //g' > $DATADIR/${recname}_capture_crop.ascii

    selection=$(awk  '
        BEGIN {
            entry=-1
            selectstart=-1
            selectend=-1
            error=-1
        }
        {
            if (length==10) {
                if (priorleng==0) {
                    if (selectstart==-1)
                        selectstart=entry+1
                    else if (selectend==-1)
                        selectend=entry
                    else
                        error=entry
                }
            }
            else if (length>0) {
                if (priorleng==0)
                    entry++
            }
            priorleng=length
        }
        END {
            if (selectstart == selectend && error == -1)
                print selectstart
            else
                print "ERROR: selectstart:" selectstart " selectend:" selectend " error:" error > "/dev/stderr"
        }
        ' $DATADIR/${recname}_capture_crop.ascii)
}


# Get menu selection. Must be preceded by capturepage to capture the menu.
# Return:
# menuitems - array of menu items
# selection - index of selected item or blank if error
function getmenuselection {
    convert $DATADIR/${recname}_capture_crop.png -gravity West -crop 25%x100% $DATADIR/${recname}_capture_crop.jpg
    jp2a --width=50 -i --red=1 --green=0 --blue=0 $DATADIR/${recname}_capture_crop.jpg \
      | sed 's/ //g' > $DATADIR/${recname}_capture_crop.ascii
    # 7 blank rows between each, but selected one removed and 15 blank rows there
    # each entry 2-3 rows
    tesseract $DATADIR/${recname}_capture_crop.jpg - 2>/dev/null | sed  '/^$/d' > $DATADIR/${recname}_capture_crop.txt
    mapfile -t menuitems < <(cat $DATADIR/${recname}_capture_crop.txt)

    selection=$(awk  '
        BEGIN {
            blank=0
            nonblank=0
            entry=-1
            selection=-1
            error=0
        }
        {
            if (length < 3) {
                blank++
                nonblank = 0
            }
            else {
                if (nonblank == 0)
                    entry++
                nonblank++
                #~ print "blank " blank " entry " entry > "/dev/stderr"
                if (blank > 7) {
                    if (selection >= 0) {
                        print "ERROR: multiple selected: " selection " and " entry > "/dev/stderr"
                        error = 1
                    }
                    else
                        selection = entry
                    entry++
                }
                blank=0
            }
        }
        END {
            if (!error) {
                if (blank > 5 && selection < 0)
                    selection = entry + 1
                print selection
            }
        }
        ' $DATADIR/${recname}_capture_crop.ascii)
    if [[ "$selection" == "" ]] ; then
        echo `$LOGDATE` "ERROR: Failed to find menu selection"
    else
        echo `$LOGDATE` "Menu selection: ${menuitems[selection]}"
    fi
}
