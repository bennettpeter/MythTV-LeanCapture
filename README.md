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
- This depends on the User interface of the Stream App. If that changes significantly, this will no longer work.
- The fire stick sometimes needs powering off and on again if it loses its ethernet connection. This is not a hard failure, it can continue on wifi until reset.
- Occasionally it resets its display resolution to the default. This is not a hard failure, it may use extra bandwidth until reset.

## Hardware required

- Amazon Fire Stick or Fire Stick 4K.
- USB Capture device. There are many brands available from Amazon. Those that advertize 3840x2160 input and 1920x1080 output, costing $5 and up, have been verified to work. These are USB 2 devices.
- USB 2 or 3 extension cable, 6 inches or more. Stacking the fire stick behind the capture device directly off the MythTV backend without an extension cable is unstable.
- Optional ethernet adapter for fire stick (recommended). You can either use the official Amazon fire stick ethernet adapter or a generic version, also available from Amazon.
- You can use additional sets of the above three items to support multiple recordings at the same time.
- MythTV backend on a Linux device. This must have a CPU capable of real-time encoding the number of simultaneous channels you will be recording.

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

Note that Ubuntu has an obsolete version of adb in apt. Get the latest version from https://developer.android.com/studio/releases/platform-tools . Place adb on your path, e.g. in /usr/local/bin .

Once the prerequisites have been installed, install the scripts using by running ./install.sh. This will need to be run in root or by using sudo.

The install.sh script tests for the presence of required versions and stops if they are not present.

The install script assumes user id mthtv, group id mythtv, and script directory /opt/mythtv/bin. You can use different values by setting appropriate environment variables before running install.sh.

### Fire stick



