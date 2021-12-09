# MythTV-LeanCapture

Users of cable systems in the USA, and Comcast in particular, require a cable card device such as Ceton or Silicondust to record programming. Ceton and Silicondust devices are no longer manufactured and it seems cable cards are being phased out.

Here is an alternative method for recording channels on Comcast. It may be extendable to other providers.

## Advantages

- Do not need a cable card device
- You can record all channnels, including those Comcast has converted to IPTV.
- Avoids pixelation caused by poor signals.
- All recordings use H264 encoding. They use less disk space than recordings from a cable card device, including programs that Comcast already encodes in H264.

## Disadvantages

- Only records stereo audio.
- Does not support closed captions. *Note* It is possible to record with captions enabled to get "Burned in" captions, but some change to the code will be needed. Let me know by opening a ticket if you need this.
- If the user interface of the Stream App changes significantly, this code will need changes.
- The fire stick sometimes needs powering off and on again if it loses its Ethernet connection. This is not a hard failure, it can continue on WiFi until reset.
- Occasionally the fire stick resets its display resolution to the default. This is not a hard failure, it may use extra bandwidth until reset.
- Other occasional problems are documented in the Troubleshooting section below.

## Other Uses

The code here can be used for other purposes than MythTV capture.

- Download a list of your available channels and use the list to populate the MythTV listings with all of the channels you are permitted to watch, and only those channels. This way you do not miss anything you are permitted to watch, and you don't have failed recordings when it tries to record from an unauthorized channel. See "Setup the channel list" below.
- Transfer your Xfinity cloud DVR recordings to your local hard drive and watch them using MythTV or any other video player. See "Xfinity DVR" below.
- Transfer videos or movies from Peacock, Amazon, Hulu, etc. to your local hard drive and watch them using MythTV or any other video player. See "Manual Recordings" below.

## Hardware required

- Amazon Fire Stick or Fire Stick 4K. Note that this has only been tested with Fire Stick 4K. If a non-4K fire stick is used, it may take longer to tune and some timeouts in the code may need to be changed.
- USB Capture device. There are many brands available from Amazon. Those that advertize 3840x2160 input and 1920x1080 output, costing $5 and up, have been verified to work. These are USB 2 devices. Running `lsusb` with any of them mounted shows the device with `ID 534d:2109`.
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

Once the prerequisites have been installed, install the scripts by cloning from github and running

    sudo ./install.sh

The install.sh script tests for the presence of required versions and stops if they are not present.

The install script assumes the mythbackend user id is mythtv, and group id is mythtv. It assumes script directory /opt/mythtv/leancap. You can use different values by setting appropriate environment variables before running install.sh the first time.

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
        adb connect <IP address or name>

1. Respond to the confirmation message that appears on the fire stick display in vlc, and confirm that it must always allow connect from that system.

## Operation mode

Channel tuning in the xfinity stream app is by arrowing up an down through a list. There is no way of keying a channel number. This can be time consuming since there are hundreds of channels.

The system uses OCR to see the channel numbers. Occasionally a number is interpreted incorrectly. In all cases I have tried, the error is corrected by the script automatically. However there is a possibility this may cause a failure.

There is a script to download a list of channel numbers from the fire stick and store it on the backend. This speeds up the tuning process and is used for correcting OCR errors. With the list in place, it can tune from channel 15 to channel 702 in 9 seconds. Without the list it takes 23 seconds. Also without the list there is a risk of tuning the wrong channel due to OCR errors.

## Configuration

### Linux

#### /etc/opt/mythtv/leancap.conf

- DATADIR and LOGDIR: I recommend leave these as is. Change them if you need to store data files and logs in a different location. Note that the default directories are created by install. If you change the names here, you must create those directories manually and change ownership to mythtv.
- VID_RECDIR: Optional. You need to specify a video storage directory here if you want to use leanxdvr or leanfire. These are not part of the lean recorder. leanxdvr can be used for recording programs from the Xfinity cloud DVR and adding them to your videos collection. leanfire can be used for recording other content from the fire stick (e.g. Youtube videos).
- NAVTYPE: Leave as "All Channels". Default "All Channels".
- MAXCHANNUM: Enter the highest channel number you use. I recommend using 999. Comcast has a policy of numbering all channels with numbers below 1000, and then duplicating the channels in numbers above that. If you want to use those higher numbers for recording, set this to the highest number channel available. If you set it higher than what is present in Comcast, you will get errors in the leancap_chanlist script.
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
- Starting Channel: Set a value that is in your channel list.
- Interactions Between Inputs
    - Max Recordings: 2
    - Schedule as Group: Checked
    - Input Priority: 0 or other value as needed to determine which device is used.
    - Schedule Order: Set to sequence order for using vs other capture cards. Set to 0 to prevent recordings on this device.
    - Live TV Order:  Set to sequence order for using vs other capture cards. Set to 0 to prevent Live TV on this device.

#### Frontend Setup

In mythfrontend, set up the following. Note this is a global setting, you do not need to set it up in each front end. This will attempt to prevent losing some 40 seconds when one show follows another on a different channel, by allocating a different tuner. This is only useful if you have two or more capture devices. If it is not possible to avoid back to back recordings it will do them anyway and you may lose 40 seconds from the beginning of the second recording.

mythfrontend -> Setup -> Video -> Recording Priorities -> Set Recording Priorities -> Scheduler Options -> Avoid Back to Back Recordings -> Different Channels

The following setting will reduce the chances of losing the first seconds of a show due to the time taken to tune:

mythfrontend -> Setup -> Video -> General -> General (Advanced) : Set time to record before start of show to 60.

The following setting available on V32 will prevent MythTV from marking a recording as failed if the first 60 seconds are missing due to tuning delay

mythfrontend -> Setup -> Video -> General -> General (Advanced) : Set maximum start gap to 60 and minimum recording quality to 95.

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

    All Channels
    *****
    disconnected fire-office-eth

Press ctrl-c to end the script, which otherwise repeats the process every 5 minutes.

Run vlc and open the video card. You should see the page of "Favorite Channels" and the channel numbers and programs displayed. Close vlc.

Repeat the menu navigation test for each tuner if you have more than one.

### Setup the channel list.

This creates your channel list in /var/opt/mythtv/All Channels.txt

    sudo -u mythtv bash
    /opt/mythtv/leancap/leancap_chanlist.sh leancap1

This takes about 3 minutes. After it has run, it may report errors. The errors are reported and also stored in /var/opt/mythtv/All Channels_errors.txt. For example:

    Line 63 12 changed to 110

This tells you an error was found in line 63 of the output file and needs to be fixed. The number 12 was changed to 110 to fix the error but this is probably not the correct fix. Copy /var/opt/mythtv/All Channels_gen.txt to /var/opt/mythtv/All Channels.txt and fix the errors there. Edit that file, look for line 63. Look at your comcast channel lineup and if the number it put there (e.g.110) is incorrect, fix it

After setting up the channel list, you have a listing of all the channels that you can receive. If you are using schedules direct with tv_grab_zz_sdjson_sqlite, you can use this list to make sure that all of your channels are in the listings and none of the channels you are not permitted to view have listings. Copy the "/var/opt/mythtv/All Channels.txt" file to a new file in another location. Edit that file to create sql statements as follows. This assumes you have already set up the channels in sqlite:

    update channels set selected = 0;
    update channels set selected = 1 where channum = 2;

Repeat the second line for all channels in the list. Run it against your sqlite database (assuming channelfile is the file you created):

    sudo -u mythtv bash
    sqlite3 SchedulesDirect.DB < channelfile

### Third test to check tuning.

Note that while running the test it is important that vlc **not** be open on the video card.

Make sure you have set up the channel list in `/var/opt/mythtv/All Channels.txt` as described above.

    sudo -u mythtv bash
    /opt/mythtv/leancap/leancap_tune.sh leancap1 704

where 704 is the number of one of your channels that is in your list.

You should see a bunch of messages ending with "Complete tuning channel: 704 on recorder: leancap1". Start vlc and open the video card. You should see video playing from the selected channel. Press the back button on your fire remote to end it or it will continue playing for ever. Close vlc.

Note you can also add a NOPLAY parameter to tune the channel and leave it selected in the list:

    sudo -u mythtv bash
    /opt/mythtv/leancap/leancap_tune.sh leancap1 704 NOPLAY

Repeat the tuning test on other tuners.

### Activate the setup.

Enable the leancap-scan service:

    sudo systemctl enable leancap-scan.service

Reboot so that the udev setting can take effect and the leancap-scan service can be started. Look in the log directory /var/log/mythtv_scripts to see if there are any errors displayed in the leancap_scan or leancap_ready logs.

You must not open the video device with vlc if any recording is scheduled to start. Recordings cannot be done while it is open in vlc.

Periodically run the script to setup the channel list, in case it changes. The script is set up so that if there is no change, nothing will be done. If there is a change and there is no error that needs fixing, it will automatically overwrite the list. In there is a change and there is an error it will email you. Also the script is set up so that if a recording needs to start while the script is running, the script will stop so that recording can continue.

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

        sudo systemctl start leancap-scan.service

### Manual Recordings

This can be done without MythTV. You don't need MythTV installed. You can run this on a separate machine. Also you do not need to be an Xfinity or Comcast user, this can be used to record anything that shows on a fire stick.

If you are not using MythTV backend on the machine, install the software as described above. You will not do the MythTV configuration. Do not enable the leancap_scan service.

Manually run the scan using terminal. This has to be done again if you have rebooted or replugged usb devices since it was last run:

    /opt/mythtv/leancap/leancap_scan.sh

Note the leancap_scan will fail if you do not have Xfinity installed and activated. In that case you will have to manually place the AUDIO_IN and VIDEO_IN values in the leancap1.conf file. You can find out the values by experimenting with vlc. Note that these can change when rebooting or replugging usb devices.

If that is successful, run leanfire in terminal:

    /opt/mythtv/leancap/leanfire.sh

This will display a message ending with "Type Y to start"

Start vlc and open the fire stick capture device. Use the remote to navigate to the show or video you want to record. Get to the point where pressing enter on your remote would start playback. Do not press enter on your remote.

Type Y <enter> in the terminal window. vlc will close, the script will send the Enter button and ffmpeg will start recording. Leave the terminal window open. In file manager look for the video directory (directory specified by VID_RECDIR= in /etc/opt/mythtv/leancapture.conf). You should see an mkv file there with the current date and time as name. Refresh until that file is at least 1MB, then you can open it with vlc. See if your recording is going OK. Close vlc and let it continue recording.

There is a time limit of 6 hours. Recording stops after 6 hours or after playback stops. When playing a video from Xfinity, normally at the end it stops on a blank screen. When this happens the recording will stop. Other services like Hulu, will automatically start the next episode or some other show when the show ends, in which case the next show will also record.

To check if your recording is done and if it is busy recording some other show you don't want, open the mkv file in vlc and skip to near the end. If if is recording stuff you don't want, press Control-C in the terminal window and that will end recording.

When recording ends for any reason, whether time limit, blank screen or control-C, the script navigates the fire stick back to the home screen.

There are some input parameters available to vary the defaults. To see the syntax run:

    /opt/mythtv/leancap/leanfire.sh -h

### Xfinity DVR

This can be done without MythTV. You don't need MythTV installed. You can run this on a separate machine. This does require you to be a Comcast customer and to have the Xfinity Cloud DVR feature in your plan. Using the fire stick app, the android app or Firefox browser, you can search program names and set them to record from your subscribed channels.

When you have one or more programs recorded on Xfinity, you can use this script to get them into mkv files on your computer. Why do this? Xfinity only gives 20 hours of recording by default and also only allows you to keep your recordings for 1 year.

Manually run the scan using terminal. This has to be done again if you have rebooted or replugged usb devices since it was last run:

    /opt/mythtv/leancap/leancap_scan.sh

If that is successful, run the leanxdvr in terminal:

    /opt/mythtv/leancap/leanxdvr.sh

This will immediately navigate to your recordings on the fire stick and record them into files in the video directory (directory specified by VID_RECDIR= in /etc/opt/mythtv/leancapture.conf). Each file is placed in a subdirectory of the series name and the file is named with the season, episode and subtitle. You need not do anything, it will transfer all your recordings and delete them from Xfinity.

While recording is in progress you can check it by opening the mkv files with vlc. Note the files are named with only season and episode until the recording ends, at which time the subtitle is added to the name.

There is no option to prevent recordings being deleted from Xfinity after being recorded to your local drive. Xfinity has a recover deleted option but that does not work once all shows have been deleted.

If the process is interrupted (e.g. by control-C in the terminal window), one recording will be incomplete. You can start the script again and it will restart the incomplete recording from the beginning again, so you won't lose anything.

### XFinity Video on Demand

Some series are available fro streaming for a time after the broadcast. Some may also be available for an extended time. There is a script to record from these.

The same comments apply as for XFinity DVR regarding installation and running scan.

Run this command in terminal. Without parameters it shows you the command syntax.

    /opt/mythtv/leancap/leanxvod.sh

Required parameters are title, season, episode. It is best to first logon to the fire stick and search the XFinity application to make sure what is available. Only "free to you" episodes can be recorded here.

You can record a bunch of episodes by putting them in a script and running it. For example put the following in a file and run it. This is useful if you missed some episodes.

    #!/bin/bash
    /opt/mythtv/leancap/leanxvod.sh -t "Young Sheldon" --season 5 --episode 5
    /opt/mythtv/leancap/leanxvod.sh -t "Young Sheldon" --season 5 --episode 6
    /opt/mythtv/leancap/leanxvod.sh -t "Chicago P.D." --season 9 --episode 7
    /opt/mythtv/leancap/leanxvod.sh -t "Chicago P.D." --season 9 --episode 8

Each episode is written to a file in a subdirectory of the VID_RECDIR from leancapture.conf. Each recording is placed in a sub directory names for the series title, with the recording being named with original airdate, season and episode, and subtitle.

### Unplugging or Replugging any USB devices

If any usb capture devices are unplugged or replugged, you need to restart the service:

    sudo systemctl restart leancap-scan.service

or, if this is not a backend, just run the scan again:

    /opt/mythtv/leancap/leancap_scan.sh

The series name must be an exact match. The script is prone to OCR errors. There is code to fix errors that I found, but there could still be problems. If there is an error the script cannot recover from, it will terminate without recording.

Please feel free to open a support ticket for any specific errors.

If a recording fails, you can use the leanfire to record it (see Manual Recordings above), but that will require you to manually find the show on the fire stick before starting the recording. You cannot set up a script to record multiple episodes this way.

## Troubleshooting

- Fire stick loses ethernet connection. Randomly, once every few months, a fire stick reverts to wifi. This may not be a problem. It can still record over wifi, but it is best to reset it to ethernet. An email is sent by the scripts when this happens. This happens equally with Amazon's ethernet adapter and third party ethernet adapters.  The only solution I have found is to disconnect power from teh fire stick and reconnect. Rebooting the fire stick from the settings menu does not fix it, it still only recognizes wifi after the reboot.  If anybody finds a better solution please let me know.
- Fire stick reverts to default resolution. Randomly, once every few months, a fire stick reverts to auto resolution, even if you have set it specifically. Recordings still continue as normal, videos being resized in the usb adapter. The scripts send an email message when this happens. The solution is to use the settings on the fire stick to reset it to your desired resolution.
- Interruptions during recording. If Xfinity stops because of a network error, sometimes it displays a message that says "Try again later" or something equally useless. The script will try re-tuning after a couple of minutes. It will keep trying to re-tune until the end of the show. This has happened only a couple of times in six months with hundreds of recordings. This may also happen if you lose internet connection. Also if you accidentally press home or return on the remote. When this happens the script sends an email message to let you know it is retrying.
- Recordings happen without audio. This has happened once to me. All recordings from a certain time onwards were silent. The problem was in the capture device. Re-powering the fire stick and rebooting the backend made no difference. It was solved by unplugging the usb device and replugging it, thereby effectively rebooting the usb device. I have added code to a userjob that runs after every recording to check if there is audio and send an email if there is not. That user job is at https://github.com/bennettpeter/mythscripts/blob/master/install/opt/mythtv/bin/userjob_recording.sh . Note that this job is highly dependent on my own setup. The relevant code from the job is below. You need to figure out how to get the variables set up. You will need ffmpeg and sox installed.

Code to check for audio

    # Examine 1 minute of audio at 5 minutes in
    # Returns "Mean    norm:          0.010537"
    soxstat=($(ffmpeg -i "$fullfilename" \
        -ss 00:05:00 -t 00:01:00.0 -vn -ac 2 -f au - 2>/dev/null \
        | sox -t au - -t au /dev/null  stat |& grep norm:))
    if [[ ${soxstat[2]} != ?.?????? ]] ; then
        "$scriptpath/notify.py" "sox failed" "$title $subtitle - sox said ${soxstat[@]}"
    elif [[ ${soxstat[2]} < 0.001000 ]] ; then
        "$scriptpath/notify.py" "$type failed" "$title $subtitle has audio level ${soxstat[2]}"
    fi
