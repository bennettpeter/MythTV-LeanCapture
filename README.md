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
- If the user interface of the Stream App changes significantly, this capture will need changes.
- The fire stick sometimes needs powering off and on again if it loses its Ethernet connection. This is not a hard failure, it can continue on WiFi until reset.
- Occasionally the fire stick resets its display resolution to the default. This is not a hard failure, it may use extra bandwidth until reset.
- You have to set up a list of channels that you use for recordings.

## Hardware required

- Amazon Fire Stick or Fire Stick 4K.
- USB Capture device. There are many brands available from Amazon. Those that advertize 3840x2160 input and 1920x1080 output, costing $5 and up, have been verified to work. These are USB 2 devices. Running `lsusb` with any of them shows the device with `ID 534d:2109`.  
- USB 2 or USB 3 extension cable, 6 inches or more. Stacking the fire stick behind the capture device directly off the MythTV backend without an extension cable is unstable.
- Optional Ethernet adapter for fire stick (recommended). You can either use the official Amazon fire stick Ethernet adapter or a generic version, also available from Amazon.
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

Connect each fire stick to a capture device, Ethernet adapter, and power supply. If you do not have an Ethernet adapter you can use WiFi. Connect each to a USB socket on the MythTV backend.

## Software installation

### Linux Machine

Prerequisite software for these scripts can be installed on Linux with the distribution package manager.

- vlc or obs-studio
- tesseract-ocr
- gocr
- ffmpeg
- imagemagick
- jp2a
- adb version 1.0.41 or later

Note that Ubuntu has an obsolete version of adb in apt. Do not use the out of date version. It does not work with these scripts. Get the latest version from https://developer.android.com/studio/releases/platform-tools . Place adb on your path, e.g. in /usr/local/bin.

Once the prerequisites have been installed, install the scripts by running

    sudo ./install.sh.

The install.sh script tests for the presence of required versions and stops if they are not present.

The install script assumes the mythbackend user id is mthtv, and group id is mythtv. It assumes script directory /opt/mythtv/leancap. You can use different values by setting appropriate environment variables before running install.sh.

If there is a new or updated version of the scripts, just run the ./install.sh again. It will not overwrite settings files you have updated.

### Fire stick

In order to operate your fire stick while connected to MythTV:

1. Press Home on the Fire Stick Remote. 
1. Run vlc on the backend. 
1. Select Media, Open Capture device. Select the Video Device /dev/video0 or other even numbered device. Do not select an odd numbered device.
1. Check if your fire stick home screen is displayed. If you have multiple fire sticks, press buttons on the remote to see whether the correct one is displayed. If not, open the next Capture Device (e.g. /dev/video2). **Note:** The picture may not look good, response may lag, and videos may display like slide shows. Do not worry, this is because vlc does not use optimal settings by default. The display will be good enough for installing apps and changing settings. When you do actual recordings it uses ffmpeg and they look much better.
1. Connect to your WiFi system.
1. Hook up Ethernet if you will be using that and ensure it connects. The WiFi connection will be used as a backup in case the Ethernet connection fails. This happens occasionally, the fire stick reverts to WiFi for no reason.
1. Create a reserved IP address in your router for both the Ethernet and WiFi IP addresses.
1. Make a note of the IP addresses for each fire stick.
1. Optional - add the fire stick IP addresses with useful names to the backend hosts file to make configuration easier.
1. Install and activate the Xfinity Stream App. You need a comcast cable subscription in order to activate it.
1. Disable screen saver.
1. Set screen resolution to the resolution you will be recording. The capture devices mentioned above can handle 1920x1080 at 30fps or 1280x720 at 60fps. The actual resolution recorded is controlled by a setting in /etc/opt/mythtv/leancap1.conf. If that is different from the fire tv setting, the video is resized by the capture device. You could leave the resolution here as the default and let the capture device do the resize, but you may then be using more internet bandwidth than needed.
1. Disable automatic updates.
1. Enable developer mode.
1. Switch to user mythtv and run adb against the fire stick Ethernet address.

        sudo -u mythtv bash
        adb connect <IP address  or name>

1. Respond to the confirmation message that appears on the fire stick display in vlc, and confirm that it must always allow connect from that system.

## Configuration

### Xfinity

The "tuning" of channels on the stream app requires selecting the channel from a list. There is no option of entering a channel number. Since the list of channels can run into the hundreds, tuning could take minutes. To avoid this problem, we use the "favorite channels", where you can select the actual channels you will record.

There is a script that runs at startup and once a day that will notify you by email, text message or log message if there are channels set up for recordings that are not in the favorites list. It looks two weeks ahead so you have time to get them added.

The Xfinity app on the fire stick is not able to set up favorite channels. Either log in to the Xfinity.com web site and select streaming to set up the favorites, or install the Xfinity stream app on an android phone and set them up there. Note that the Xfinity stream web site fails on Chrome under Linux, but it works on Firefox under Linux.

### Linux

#### /etc/opt/mythtv/leanchans.txt

This needs to have a list of the favorite channels set up in the Xfinity stream app. Type one number per line. They must be in numerical ascending order, with no leading zeroes. This must match what is set up in Xfinity. Note that when you add a channel to favorites it sometimes adds the channel twice, an extra copy of the channel in the 1000 plus range. Add any extra numbers to leanchans.txt as well, so that there is a match between what is in Xfinity and leanchans.txt.

#### /etc/opt/mythtv/leancap.conf

- DATADIR and LOGDIR: I recommend leave these as is. Change them if you need to store data files and logs in a different location. Note that the default directories are created by install. If you change the names here, you must create those directories manually and change ownership to mythtv.
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

Enable the leancap-scan service:

    sudo systemctl enable leancap-scan.service

Reboot so that the udev setting can take effect and the leancap-scan service can be started. Look in the log directory /var/log/mythtv_scripts to see if there are any errors displayed in the leancap_scan or leancap_ready logs.

You must not open the video device with vlc if any recording is scheduled to tart. Recordings cann be done while it is open in vlc.

### Fire Stick 

While the fire stick is set up as a capture device, it is dedicated to that task. You cannot use it for any other apps. Put the remote in a safe place where nobody will touch it. To be extra sure remove its battery.

Any time you need to do any work on a fire stick (reset resolution, update, etc.), you  need to do as follows.

- Make sure nothing is scheduled to record in the near future.
- Stop the service:

    sudo systemctl stop leancap-scan.service

- Run vlc and open the video capture device (/dev/video*). You can find which the capture device is by looking in /var/opt/mythtv/leancapx.conf where x is the number of the one you are working on.
- Use the fire stick remote to perform any needed work.
- Close vlc
- Start the service again:

    sudo systemctl stop leancap-scan.service

### Manual Recordings

This can be done without MythTV. You don't need MythTV installed. You can run this on a separate machine. Also you do not need to be an Xfinity or Comcast user, this can be used to record anything that shows on a fire stick.

If you are not using MythTV backend on the machine, install the software as described above. You do not need to create leanchans.txt. You will not do the MythTV configuration. Do not enable the leancap_scan service.

Manually run the scan using terminal. This has to be done if you have rebooted or replugged usb devices since it was last run:

    /opt/mythtv/leancap/leancap_scan.sh

Note the leancap_scan will fail if you do not have Xfinity installed and activated. In that case you will have to manually place the AUDIO_IN and VIDEO_IN values in the leancap1.conf file. You can find out the values by experimenting with vlc. Note that these can change when rebooting or replugging usb devices.

If that is successful, run the leanfire in terminal:

    /opt/mythtv/leancap/leanfire.sh

This will display a message ending with "Type Y to start"

Start vlc and open the fire stick capture device. Use the remote to navigate to the show or video you want to record. Get to the point where pressing enter on your remote would start playback. Do not press enter on your remote.

Type Y <enter> in the terminal window. vlc will close, the script will send the Enter button and ffmpeg will start recording. Leave the terminal window open. In file manager look for the video directory (directory specified by VID_RECDIR= in /etc/opt/mythtv/leancapture.conf). You should see an mkv file there with the current date and time as name. Refresh until that file is at least 1MB, then you can open it with vlc. See if your recording is going OK. Close vlc and let it continue recording.

There is a time limit of 6 hours. Recording stops after 6 hours or after playback stops. When playing a video from Xfinity, normally at the end it stops on a blank screen. When this happens the recording will stop. Other services like Hulu, will automatically start the next episode or some other show when the show ends, in which case the next show will also record.

To check if your recording is done and if it is busy recording some other show you don't want, open the mkv file in vlc and skip to near the end. If if is recording stuff you don't want, press Control-C in the terminal window and that will end recording.

When recording ends for any reason, whether time limit, blank screen or control-C, the script navigates the fire stick back to the home screen.

### Xfinity DVR

This can be done without MythTV. You don't need MythTV installed. You can run this on a separate machine. This does require you to be a Comcast customer and to have the Xfinity Cloud DVR feature in your plan. Using the fire stick app, the android app or Firefox browser, you can search program names and set them to record from your subscribed channels.

One you have one or more programs recorded on Xfinity, you can use this script to get them onto mkv files on your computer. Why do this? Xfinity only gives 20 hours of recording by default and also only allows you to keep your recordings for 1 year.

Manually run the scan using terminal. This has to be done if you have rebooted or replugged usb devices since it was last run:

    /opt/mythtv/leancap/leancap_scan.sh

If that is successful, run the leanxdvr in terminal:

    /opt/mythtv/leancap/leanxdvr.sh

This will immediately navigate to your recordings on the fire stick and record them into files in the video directory (directory specified by VID_RECDIR= in /etc/opt/mythtv/leancapture.conf). Each file is placed in a subdirectory of the series name and the file is named with the season, episode and subtitle. You need not do anything, it will transfer all your recordings and delete them from Xfinity.

While recording is in progress you can check it by opening the mkv files with vlc. Note the files are named with only season and episode until the recording ends, at which time the subtitle is added to the name.

There is no option to prevent recordings being deleted from XFinity after being recorded to your local drive. XFinity has an undelete option but that does not work once all shows have been deleted.

If the process is interrupted (e.g. by control-C in the terminal window), one recording will be incomplete. You can start the script again and it will restart the incomplete recording from the beginning again, so you won't lose anything, just some time.

### Unplugging or Replugging any USB devices

If any usb capture devices are unplugged or replugged, you need to restart the service:

    sudo systemctl restart leancap-scan.service

or, if this is not a backend, just run the scan again:

    /opt/mythtv/leancap/leancap_scan.sh
