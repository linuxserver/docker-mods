# rffmpeg - Docker mod for Jellyfin

This mod adds rffmpeg to Linuxserver.io's Jellyfin https://github.com/linuxserver/docker-jellyfin. 

rffmpeg is a remote FFmpeg wrapper used to execute FFmpeg commands on a remote server via SSH. It is most useful in situations involving media servers such as Jellyfin (our reference user), where one might want to perform transcoding actions with FFmpeg on a remote machine or set of machines which can better handle transcoding, take advantage of hardware acceleration, or distribute transcodes across multiple servers for load balancing.

See https://github.com/joshuaboniface/rffmpeg for more details about rffmpeg

In Jellyfin docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:jellyfin-rffmpeg`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:jellyfin-rffmpeg|linuxserver/mods:jellyfin-mod2`

This mod requires you to update the rffmpeg.yml located in "Your jellyfin config dir"/rffmpeg/rffmpeg.yml with your remote SSH username. You also need to add your authorized SSH file to "Your jellyfin config dir"/rffmpeg/.ssh/id_rsa"

You can specify the remote SSH username and host using ENV, note currently only supports 1 host and doesn't overwrite values other than defaults:
* RFFMPEG_USER= remote SSH username
* RFFMPEG_HOST= remote server name or IP

You also need to ensure that /cache inside the container is exported on the host so it can be mapped on the remote host. Eg for docker compose. 
```yaml
    volumes:
      - "Your jellyfin config dir":/config
      - "Your jellyfin config dir"/cache:/cache
```
See https://github.com/joshuaboniface/rffmpeg/blob/master/SETUP.md NFS setup for more details
      
EXAMPLE Docker-Compose file with WOL support via API:

```yaml
---
version: "2.1"
services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - RFFMPEG_USER=jellyfin
      - RFFMPEG_WOL=api
      - RFFMPEG_HOST=transcode
      - RFFMPEG_HOST_MAC="12:ab:34:cd:ef:56"
      - WOL_API=192.168.1.5  #docker host IP
      - WOL_API_PORT=8431
      - WOL_WAIT=10  #time transcode host takes to start
    volumes:
      - /path/to/jellyfin/config:/config
      - /path/to/jellyfin/config/cache:/cache
      - /path/to/data:/data/
    ports:
      - 8096:8096
      - 8920:8920 #optional
      - 7359:7359/udp #optional
      - 1900:1900/udp #optional
    restart: unless-stopped
    depends_on:
      - wol_api
  wol_api:
     image: rix1337/docker-wol_api
     container_name: wol_api
     environment: 
       - PORT=8431
     network_mode: host
     restart: unless-stopped
```

If you want to run rffmpeg commands they must be run as ABC inside the container eg:
* To add new host ``` docker exec -it jellyfin s6-setuidgid abc /usr/local/bin/rffmpeg add --weight 1 remotehost ```
* To view status ``` docker exec -it jellyfin s6-setuidgid abc /usr/local/bin/rffmpeg status ```
* To test connection ``` docker exec -it jellyfin s6-setuidgid abc /usr/local/bin/ffmpeg -version ```
* To test connection ``` docker exec -it jellyfin s6-setuidgid abc /usr/local/bin/ffprobe -version ```
* To view all commands ``` docker exec -it jellyfin s6-setuidgid abc /usr/local/bin/rffmpeg -h ```

You then need to set your FFMPEG binary in Jellyfin to:
* /usr/local/bin/ffmpeg - Normal rffmpeg without WOL support
* /usr/local/bin/wol_rffmpeg/ffmpeg - rffmpeg with WOL support

WOL Support
Native WOL support is available if you are running in host network mode. If not you can use the WOL_API container https://hub.docker.com/r/rix1337/docker-wol_api. Note the image name is rix1337/docker-wol_api

WOL ENV:
* RFFMPEG_WOL= native or api
* RFFMPEG_HOST= remote host to wake
* RFFMPEG_HOST_MAC= remote host to wake mac enclosed in " " eg "aa:12:34:bb:cc:56" 
* WOL_API = IP of docker host
* WOL_API_PORT= port wol_api is running on
* WOL_WAIT= time in seconds to wait for host to wake
