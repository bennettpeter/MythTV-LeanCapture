# MythTV-LeanCapture

# ***This is a work in progress, not ready for use yet***

Users of cable systems in the USA, and Comcast in particular, require a cable card device such as Ceton or Silicondust to record programming. Ceton and Silicondust devices are no longer manufactured and it seems cable cards are being phased out.

Here is an alternative method for recording channels on Comcast. It may be extendable to other providers.

## Advantages

- Do not need a cable card device
- You can record all channnels, including those Comcast has converted to IPTV.
- Avoids pixelation caused by poor signals.

## Disadvantages

- Only records stereo audio.
- Does not support closed captions.
- If the User interface of the Stream App changes significantly, this capture will need changes.
- The fire stick sometimes needs powering off and on again if it loses its ethernet connection. This is not a hard failure, it can continue on wifi until reset.
- Occasionally it resets its display resolution to the default. This is not a hard failure, it may use extra bandwidth until reset.

## Hardware required

- Amazon Fire Stick or Fire Stick 4K.
- USB Capture device. There are many brands available from Amazon. Those that advertize 3840x2160 input and 1920x1080 output, costing $5 and up, have been verified to work. These are USB 2 devices. Running `lsusb` with any of them shows the device with `ID 534d:2109`.  
- USB 2 or USB 3 extension cable, 6 inches or more. Stacking the fire stick behind the capture device directly off the MythTV backend without an extension cable is unstable.
- Optional ethernet adapter for fire stick (recommended). You can either use the official Amazon fire stick ethernet adapter or a generic version, also available from Amazon.
- You can use additional sets of the above three items to support multiple recordings at the same time.
- MythTV backend on a Linux device. This must have a CPU capable of real-time encoding the number of simultaneous channels you will be recording.

### CPU power required

Since the backend will be encoding real-time, it needs sufficient CPU power. To determine how many fire sticks you can connect, find out how many encodes you can do at one time.

Run this on your backend to get a value:

    sysbench --num-threads=$(nproc) --max-time=10 --test=cpu run

Look at the resulting *events per second*. Based on my simple testing, each encode will take approximately 2000 out of this. I do not recommend loading the CPU to 100%, preferably do not go over 50%. If your *events per second* is 4000 you should only do 1 encode at a time. if it is 16000, you could theoretically do 8 at a time, but I would limit it to 4.

Since I tested on only a few backends, these figures may not be reliable. This is only a rough guide. Once you have your setup running, set a recording going and run mpstat 1 10 to see the %idle to get a better idea of how much CPU is being used.

A raspberry pi 2 shows events per second of 178. Do not try to run *LeanCapture* on a raspberry pi!

## Hardware Installation

Connect each fire stick to a capture device, ethernet adapter, and power supply. If you do not have an ethernet adapter you can use wifi. Connect each to a USB socket on the MythTV backend.

## Software installation

### MythTV Backend

After installing MythTV backend, this set of scripts can be installed.

Prerequisite software for these scripts can be installed on Linux with the distribution package manager.
- vlc or obs-studio
- tesseract-ocr
- gocr
- ffmpeg
- imagemagick
- jp2a
- adb version 1.0.41 or later

Note that Ubuntu has an obsolete version of adb in apt. Get the latest version from https://developer.android.com/studio/releases/platform-tools . Place adb on your path, e.g. in /usr/local/bin.

Once the prerequisites have been installed, install the scripts using by running ./install.sh. This will need to be run with root or using sudo.

The install.sh script tests for the presence of required versions and stops if they are not present.

The install script assumes the mythbackend user id is mthtv, and group id is mythtv. It assumes script directory /opt/mythtv/leancap. You can use different values by setting appropriate environment variables before running install.sh.

### Fire stick

In order to operate your fire stick while connected to MythTV:

1. Press Home on the Fire Stick Remote. 
1. Run vlc on the backend. 
1. Select Media, Open Capture device. Select the Video Device /dev/video0 or other even numbered device. Do not select an odd numbered device.
2. Check if your fire stick home screen is displayed. If you have multiple fire sticks, press buttons on the remote to see whether the correct one is displayed. If not, open the next Capture Device (e.g. /dev/video2).

- Connect to your wifi system.
- Hook up ethernet if you will be using that and ensure it connects. The wifi connection will be used as a backup in case the ethernet connection fails. This happens occasionally, the fire stick reverts to wifi for no reason.
- Create a reserved IP address in your router for both the ethernet and wifi IP addresses.
- Make a note of the ip addresses fir each fire stick.
- Optional - add the fire stick ip addresses with useful names to the backend hosts file to make configuration easier.
- Install and activate the Xfinity Stream App. You need a comcast cable subscription in order to activate it.
- Disable screen saver.
- Set screen resolution to the resolution you will be recording.
- Disable automatic updates.
- Activate developer mode.
- Switch to user mythtv and run adb against the fire stick ethernet address. `sudo -u mythtv bash` then `adb connect <ip address  or name>` Respond to the confirmation message that appears on teh fire stick display in vlc, and confirm that it must always allow connect from that system.


## Configuration

### Xfinity

The "tuning" of channels on the stream app requires selecting the channel from a list. There is no option of entering a channel number. Since the list of channels can run into the hundreds, tuning could take minutes. To avoid this problem, we use the "favorite channels", where you can select the actual channels you will record.

There is a script that runs at startup and once a day that will notrify you by email, text message or log message if there are channels set up for recordings that are not in the favorites list. It looks two weeks ahead so you have time to get it done.

The Xfinity app on the fire stick is not able to set up favorite channels. Either log in to the xfinity.com web site and select streaming to set up the favorites, or install the xfinity stream app on an android phone and set them up there. Note that the xfinity stream web site fails on Chrome under Linux, but it works on Firefox on Linux.

### Linux

#### /etc/opt/mythtv/leanchans.txt

This needs to have a list of the favorite channels set up in the xfinity stream app. Type one number per line. They must be in numerical ascending order, with no leading zeroes. It must match what is set up in xfinity. Note that when you add a channel to favorites it sometimes adds the channel twice, an extra copy of the channel in the 1000 plus range. Add any extra numbers to the list as well, so that there is a match between what is in xfinity and leanchans.txt.

#### /etc/opt/mythtv/leancap.conf

- DATADIR and LOGDIR: I recommend leave these as is. Change them if you need to store data files and logs in a different location.
- VID_RECDIR: Optional. You need to specify a video storage directory here if you want to use leanxdvr or leanfire. These are not part of the lean recorder. leanxdvr can be used for recording programs from the Xfinity cloud DVR and adding them to your videos collection. leanfire can be used for recording other content from the fire stick (e.g. Youtube video).
- Email settings: Fill these in to get emails and text messages when there is a problem with the capture device. If you do not want emails or text messages, set EMAIL1 nd EMAIL2 to empty. The messages will go to notify.py.log in the log directory.


#### /etc/opt/mythtv/leancap1.conf


### MythTV

## Troubleshooting

### Power failure

### Fire TV Glitches

### Taking fire stick out of service

### Replugging any USB devices

