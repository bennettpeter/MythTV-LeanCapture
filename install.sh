#!/bin/bash

if [[ "$MYTHTV_USER" == "" ]] ; then MYTHTV_USER=mythtv ; fi
if [[ "$MYTHTV_GROUP" == "" ]] ; then MYTHTV_GROUP=mythtv ; fi
if [[ "$SCRIPT_DIR" == "" ]] ; then SCRIPT_DIR=/opt/mythtv/leancap ; fi

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

adduser $MYTHTV_USER audio
adduser $MYTHTV_USER video

mkdir -p /etc/opt/mythtv
cp -n $scriptpath/settings/* /etc/opt/mythtv/
chmod 600 /etc/opt/mythtv/private.conf
chown $MYTHTV_USER:$MYTHTV_GROUP /etc/opt/mythtv/private.conf

mkdir -p $SCRIPT_DIR
cp $scriptpath/scripts/* $SCRIPT_DIR

mkdir -p /etc/systemd/system
cp $scriptpath/systemd/* /etc/systemd/system/

mkdir -p /etc/udev/rules.d
cp $scriptpath/udev/* /etc/udev/rules.d/


