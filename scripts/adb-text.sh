#!/bin/bash

# Send text to android device
# Optional Param: text string
# Optional environ param ANDROID_DEVICE set to hostname or ip address
#   of already connected device

str="$*"

devparm=
if [[ "$ANDROID_DEVICE" != "" ]] ; then
    devparm="-s $ANDROID_DEVICE"
fi

if [[ $str == "" ]] ; then
    echo Enter texte here
    read -e str
fi

if [[ $str != "" ]] ; then
    adb $devparm shell input text \""$str"\"
fi
