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

If there is a new or updated version of the scripts, just run the ./install.sh again. It will not overwrite settings files you have updated.

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
- Set screen resolution to the resolution you will be recording. The capture devices mentioned above can handle 1920x1080 at 30fps or 1280x720 at 60fps. The actual resolution recorded is controlled by a setting in /etc/opt/mythtv/leancap1.conf. If that is different from the fire tv setting, the video is resized by the capture device. YOu could leave the resolution here as the default and let the capture device do the resize, but you may then be using more internet bandwidth than needed.
- Disable automatic updates.
- Enable developer mode.
- Switch to user mythtv and run adb against the fire stick ethernet address. `sudo -u mythtv bash` then `adb connect <ip address  or name>` Respond to the confirmation message that appears on the fire stick display in vlc, and confirm that it must always allow connect from that system.

## Configuration

### Xfinity

The "tuning" of channels on the stream app requires selecting the channel from a list. There is no option of entering a channel number. Since the list of channels can run into the hundreds, tuning could take minutes. To avoid this problem, we use the "favorite channels", where you can select the actual channels you will record.

There is a script that runs at startup and once a day that will notify you by email, text message or log message if there are channels set up for recordings that are not in the favorites list. It looks two weeks ahead so you have time to get them added.

The Xfinity app on the fire stick is not able to set up favorite channels. Either log in to the xfinity.com web site and select streaming to set up the favorites, or install the xfinity stream app on an android phone and set them up there. Note that the xfinity stream web site fails on Chrome under Linux, but it works on Firefox under Linux.

### Linux

#### /etc/opt/mythtv/leanchans.txt

This needs to have a list of the favorite channels set up in the xfinity stream app. Type one number per line. They must be in numerical ascending order, with no leading zeroes. This must match what is set up in xfinity. Note that when you add a channel to favorites it sometimes adds the channel twice, an extra copy of the channel in the 1000 plus range. Add any extra numbers to leanchans.txt as well, so that there is a match between what is in xfinity and leanchans.txt.

#### /etc/opt/mythtv/leancap.conf

- DATADIR and LOGDIR: I recommend leave these as is. Change them if you need to store data files and logs in a different location. Note that the default directories are created by install. If you change the names here, you must create those direcyoreis manually and change ownership to mythtv.
- VID_RECDIR: Optional. You need to specify a video storage directory here if you want to use leanxdvr or leanfire. These are not part of the lean recorder. leanxdvr can be used for recording programs from the Xfinity cloud DVR and adding them to your videos collection. leanfire can be used for recording other content from the fire stick (e.g. Youtube videos).
- Email settings: Fill these in to get emails and text messages when there is a problem with the capture device. If you do not want emails or text messages, set EMAIL1 nd EMAIL2 to empty. The messages will go to notify.py.log in the log directory.

#### /etc/opt/mythtv/leancap1.conf

There are comment lines in the default file explaining the settings. You need to decide on the screen resolution and frame rate you want to use for recordings. The capture devices mentioned above can handle 1920x1080 at 30fps and 1280x720 at 60fps. The settings here determine what is recorded. If the fire stick uses different resolution, it will be converted in the capture device.

#### /etc/udev/rules.d/89-pulseaudio-usb.rules

This file prevents pulseaudio grabbing the audio output of your capture devices. Run `lsusb` and see if there is a value of `ID 534d:2109` in the results. This identifies the specific capture device I have listed above. If that is present you need not change this file, it is correctly set up. Otherwise identify the device id by running `lsusb -v|less` and search for "Video". Look for `ID xxxx:xxxx` in the corresponding entry and enter those values in the 89-pulseaudio-usb.rules file.


### MythTV

#### General: Shutdown/Wakeup Options

- Startup Before Recording (secs): If you use this set it to 600 seconds (10 minutes), to allow time for the scan and ready scripts to do their work before a recording starts.

#### Capture Cards

Add a capture card for each Fire Stick / Capture device.

- Card Type: External (black box) Recorder
- Command Path: As below. Change the path if you used a different install location. Set the parameter to the name of the conf file for the specific fire stick device (leancapx).


`/opt/mythtv/leancap/leancapture.sh leancap1`


- Tuning Timeout: Set to the maximum (65000)

#### Video Sources

Set up Schedules direct for Comcast as normal

#### Input Connections

For each EXTERNAL entry, set up as follows:

- Input Name: MPEG2TS
- Display Name: Your perference for identifying the fire stick
- Video Source: Name of the source you set up
- External Channel Change Command: Leave blank
- Preset Tuner to Channel: Leave Blank
- Scan for Channels: Do not use
- Fetch Channels from Listings Source: Do not use
- Starting Channel: Set a value that will be in your favorite  channels (see *Xfinity* above).
- Interactions Between Inputs
    - Max Recordings: 2
    - Schedule as Group: Checked
    - Input Priority: 0
    - Schedule Order: Set to sequence order for using vs other capture cards. Set to 0 to prevent recordings on this device.
    - Live TV Order:  Set to sequence order for using vs other capture cards. Set to 0 to prevent Live TV on this device.

If you use this device for Live TV, bear in mind that you can only select channels that are in the favorite list.

## Operation

If you have a cable card or other capture device, you can leave that in place while you test the new device or devices, or use it in conjunction with the LeanCapture device. To prevent recordings from using the new devices set the Schedule Order and Live TV order to 0.

### Test your setup.

Note that while running the test it is important that vlc **not** be open on the video card.

    sudo -u mythtv bash
    /opt/mythtv/leancap/leancap_scan.sh

You should see a bunch of messages including screen shots, ending with "Successfully created parameters in /var/opt/mythtv/leancap1.conf". If you have more that one tuner you will see the second set of messages also. If you have more than one tuner you can do them separately as follows

    sudo -u mythtv bash
    /opt/mythtv/leancap/leancap_scan.sh leancap1
    /opt/mythtv/leancap/leancap_scan.sh leancap2
    ....

This way you can see if each one is correctly initialized.

### Second test to check menu navigation

Note that while running the test it is important that vlc **not** be open on the video card.

    sudo -u mythtv bash
    /opt/mythtv/leancap/leancap_ready.sh leancap1

You should seee a bunch of screen messages, ending with

    Favorite Channels
    *****
    disconnected fire-office-eth

Press ctrl-c to end the script, which otherwise repeats the process every 5 minutes.

Run vlc and open the video card. You should see the page of "Favorite Channels" and the channel numbers and programs displayed. Close vlc.

Repeat the menu navigation test for each tuner if you have more than one.

### Third test to check tuning.

Note that while running the test it is important that vlc **not** be open on the video card.

Make sure you have set up some channels in favorites (see *Xfinity* above), and that the same list of  channels is in `/etc/opt/mythtv/leanchans.txt`

    sudo -u mythtv bash
    /opt/mythtv/leancap/leancap_tune.sh leancap1 704

where 704 is the number of one of your channels that have been added to the favorites.

You should see a bunch of messages ending with "Complete tuning channel: 704 on recorder: leancap1". Start vlc and open the video card. You should see video playing from the selected channel. Press the back button on your fire remote to end it or it will continue playing for ever. Close vlc.

Repeat the tuning test on other tuners.

### Activate the setup.

Enable the leancap-scan service

    sudo systemctl enable leancap-scan.service

Reboot so that the udev setting can take effect and the leancap-scan service can be started. Look in the log directory /var/log/mythtv_scripts to see if there are any errors displayed in the leancap_scan or leancap_ready logs.

You must not open the video device with vlc if any recording is scheduled to tart. Recordings cann be done while it is open in vlc.

### Fire Stick 

While the fire stick is set up as a capture device, it is dedicated to that task. You cannot use it for any other apps. Put the remote in a safe place where nobody will touch it. To be extra sure remove its battery.

Any time you need to do any work on the fire stick (reset resolution, update, etc.), you  need to do as follows.

### Replugging any USB devices

