A [Docker Mod](https://github.com/linuxserver/docker-mods) for the LinuxServer.io Lidarr Docker container that adds a script to automatically convert downloaded FLAC files to MP3s using ffmpeg.  Default quality is 320Kbps.

>**NOTE:** This mod support Linux OSes only.

Container info:
![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/linuxserver/mods/lidarr-flac2mp3))

# Installation
1. Pull the [linuxserver/lidarr](https://hub.docker.com/r/linuxserver/lidarr "LinuxServer.io's Lidarr container") docker image from Docker Hub:  
  `docker pull linuxserver/lidarr:latest`

2. Configure the Docker container with all the port, volume, and environment settings from the *original container documentation* here:  
  **[linuxserver/lidarr](https://hub.docker.com/r/linuxserver/lidarr "Docker container")**
   1. Add the **DOCKER_MODS** environment variable to the `docker create` command, as follows:  
      `-e DOCKER_MODS=linuxserver/mods:lidarr-flac2mp3`  

      *Example Synology Configuration*  
      ![flac2mp3](.assets/lidarr-synology.png "Synology container settings")

   2. Start the container.

3. After all of the above configuration is complete, to use ffmpeg, configure a custom script from the Settings->Connect screen and type the following in the **Path** field:  
   `/usr/local/bin/flac2mp3.sh`

## Usage
New file(s) with an MP3 extension will be placed in the same directory as the original FLAC file(s). Existing MP3 files with the same track name will be overwritten.

If you've configured the Lidarr Recycle Bin path correctly, the original audio file will be moved there.  
![warning24] **NOTE:** If you have *not* configured the Recycle Bin, the original FLAC audio file(s) will be deleted and permanently lost.

### Syntax
>**Note:** The **Arguments** field for Custom Scripts was removed in Lidarr release [v0.7.0.1347](https://github.com/lidarr/Lidarr/commit/b9d240924f8965ebb2c5e307e36b810ae076101e "Lidarr commit notes") due to security concerns.
To support options with this version and later, a wrapper script can be manually created that will call *flac2mp3.sh* with the required arguments.

The script accepts two options which may be placed in the **Arguments** field:

`[-d] [-b <bitrate>]`

The `-b bitrate` option, if specified, sets the output quality in bits per second.  If no `-b` option is specified, the script will default to 320Kbps.

The `-d` option enables debug logging.

### Examples
```
-b 320k        # Output 320 kilobits per second MP3 (same as default behavior)
-d -b 160k     # Enable debugging, and output 160 kilobits per second MP3
```

### Included Wrapper Script
For your convenience, a wrapper script to enable debugging is included in the `/usr/local/bin/` directory.  
Use this script in place of the `flac2mp3.sh` mentioned in the [Installation](./README.md#installation) section above.

```
flac2mp3-debug.sh        # Enable debugging
```

### Example Wrapper Script
To configure the last entry from the [Examples](./README.md#examples) section above, create and save a file called `wrapper.sh` to `/usr/local/bin` containing the following text:
```
#!/bin/bash

. /usr/local/bin/flac2mp3.sh -d -b 160k
```
Then put `/usr/local/bin/wrapper.sh` in the **Path** field in place of `/usr/local/bin/flac2mp3.sh` mentioned in the [Installation](./README.md#installation) section above.

### Triggers
The only events/notification triggers that have been tested are **On Release Import** and **On Upgrade**

![lidarr-flac2mp3](.assets/lidarr-custom-script.png "Lidarr Custom Script dialog")

### Logs
A log file is created for the script activity called:

`/config/logs/flac2mp3.txt`

This log can be downloaded from the Lidarr GUI under System->Log Files

Log rotation is performed, with 5 log files of 1MB each kept, matching Lidarr's log retention.
>![warning24] **NOTE:** If debug logging is enabled, the log file can grow very large very quickly.  *Do not leave debug logging enabled permanently.*

___
# Credits
This would not be possible without the following:

[Lidarr](https://lidarr.audio/ "Lidarr homepage")  
[LinuxServer.io Lidarr](https://hub.docker.com/r/linuxserver/lidarr "Lidarr Docker container") container  
[LinuxServer.io Docker Mods](https://hub.docker.com/r/linuxserver/mods "Docker Mods containers") project  
[ffmpeg](https://ffmpeg.org/ "FFMpeg homepage")

[warning]: http://files.softicons.com/download/application-icons/32x32-free-design-icons-by-aha-soft/png/32/Warning.png "Warning"
[warning24]: http://files.softicons.com/download/toolbar-icons/24x24-free-pixel-icons-by-aha-soft/png/24x24/Warning.png "Warning"
