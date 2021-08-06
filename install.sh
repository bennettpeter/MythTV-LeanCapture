#!/bin/bash

if [[ -f /etc/opt/mythtv/leaninstall.conf ]] ; then
    source /etc/opt/mythtv/leaninstall.conf
fi

if [[ "$MYTHTVUSER" == "" ]] ; then MYTHTVUSER=mythtv ; fi
if [[ "$MYTHTVGROUP" == "" ]] ; then MYTHTVGROUP=mythtv ; fi
if [[ "$SCRIPTDIR" == "" ]] ; then SCRIPTDIR=/opt/mythtv/leancap ; fi

if [[ ! -f /etc/opt/mythtv/leaninstall.conf ]] ; then
    echo Install configuration:
    echo MythTV User: $MYTHTVUSER
    echo MythTV Group: $MYTHTVGROUP
    echo Install Directory: $SCRIPTDIR
    echo To change these set MYTHTVUSER, MYTHTVGROUP, and SCRIPTDIR
    echo Type Y to continue
    read -e resp
    if [[ "$resp" != Y ]] ; then exit 2 ; fi
    mkdir -p /etc/opt/mythtv
    echo "MYTHTVUSER=$MYTHTVUSER" > /etc/opt/mythtv/leaninstall.conf
    echo "MYTHTVGROUP=$MYTHTVGROUP" >> /etc/opt/mythtv/leaninstall.conf
    echo "SCRIPTDIR=$SCRIPTDIR" >> /etc/opt/mythtv/leaninstall.conf
fi

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

err=0
if ! which adb >/dev/null ; then
    echo "ERROR adb is not installed"
    err=1
else
    adbver=$(adb version|head -1|sed 's/^.* //')
    reqdver=1.0.41
    lower=$(printf "$reqdver\n$adbver"|sort -V|head -1)
    if [[ "$lower" != "$reqdver" ]] ; then
        echo "ERROR Incorrect version of adb $adbver, need $reqdver"
        err=1
    fi
fi
if ! which tesseract >/dev/null ; then
    echo ERROR tesseract-ocr is not installed
    err=1
fi
if ! which gocr >/dev/null ; then
    echo ERROR gocr is not installed
    err=1
fi
if ! which ffmpeg >/dev/null ; then
    echo ERROR ffmpeg is not installed
    err=1
fi
if ! convert -version | grep -i imagemagick >/dev/null ; then
    echo ERROR imagemagick is not installed
    err=1
fi
if ! which jp2a >/dev/null ; then
    echo ERROR jp2a is not installed
    err=1
fi

if ! which vlc >/dev/null && ! which obs >/dev/null; then
    echo WARNING you will need vlc or obs-studio installed to configure your system
fi

if (( err )) ; then
    exit 2
fi

set -e

adduser $MYTHTVUSER audio
adduser $MYTHTVUSER video

export MYTHTVUSER SCRIPTDIR

mkdir -p /etc/opt/mythtv
cp -n $scriptpath/settings/* /etc/opt/mythtv/
envsubst < $scriptpath/settings/leancap1.conf > /etc/opt/mythtv/leancap1.conf
chmod 600 /etc/opt/mythtv/private.conf
chown $MYTHTVUSER:$MYTHTVGROUP /etc/opt/mythtv/private.conf


mkdir -p $SCRIPTDIR
cp $scriptpath/scripts/* $SCRIPTDIR

mkdir -p /etc/systemd/system
envsubst < $scriptpath/systemd/leancap-scan.service > /etc/systemd/system/leancap-scan.service

mkdir -p /etc/udev/rules.d
cp -n $scriptpath/udev/* /etc/udev/rules.d/

echo "Install completed successfully"
