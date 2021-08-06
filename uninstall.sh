#!/bin/bash
set -e
if [[ -f /etc/opt/mythtv/leaninstall.conf ]] ; then
    source /etc/opt/mythtv/leaninstall.conf
else
    echo "ERROR, LeanCapture is not installed"
    exit 2
fi

echo "Are you sure you want to uninstall LeanCapture?"
echo Type Y to continue
read -e resp
if [[ "$resp" != Y ]] ; then exit 2 ; fi

rm -rf  "$SCRIPTDIR"
rm /etc/opt/mythtv/leancapture.conf
rm /etc/opt/mythtv/leancap?.conf
rm /etc/opt/mythtv/leanchans.txt
rm /etc/opt/mythtv/leaninstall.conf
systemctl stop leancap-scan.service
systemctl disable leancap-scan.service
rm /etc/systemd/system/leancap-scan.service
rm /etc/udev/rules.d/89-pulseaudio-usb.rules

echo "Uninstall completed successfully"
