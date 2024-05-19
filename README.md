# rffmpeg - Docker mod for Jellyfin

This mod adds rffmpeg to Linuxserver.io's Jellyfin https://github.com/linuxserver/docker-jellyfin. 

rffmpeg is a remote FFmpeg wrapper used to execute FFmpeg commands on a remote server via SSH. It is most useful in situations involving media servers such as Jellyfin (our reference user), where one might want to perform transcoding actions with FFmpeg on a remote machine or set of machines which can better handle transcoding, take advantage of hardware acceleration, or distribute transcodes across multiple servers for load balancing.

See https://github.com/joshuaboniface/rffmpeg for more details about rffmpeg

In Jellyfin docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:jellyfin-rffmpeg`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:jellyfin-rffmpeg|linuxserver/mods:jellyfin-mod2`

This mod requires you to add your preferred SSH ID to "Your jellyfin config dir"/rffmpeg/.ssh/id_rsa". This ID also needs to be able to ssh into your remote Transcode host.

You also need to ensure that /cache inside the container is exported on the host so it can be mapped on the remote transcode host. Eg for docker compose. 
```yaml
    volumes:
      - "Your jellyfin config dir":/config
      - "Your jellyfin config dir"/cache:/cache
```
See https://github.com/joshuaboniface/rffmpeg/blob/master/SETUP.md NFS setup for more details
      
EXAMPLE Docker-Compose file:

```yaml
---
services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000 # Docker host user for folder mapping
      - PGID=1000 # Docker host group for folder mapping
      - TZ=Europe/London # timezone
      - RFFMPEG_USER=jellyfin # ssh user for rffmpeg, added to rffmpeg.yml located in "Your jellyfin config dir"/rffmpeg/rffmpeg.yml on first run only
      - RFFMPEG_HOST=transcode # DNS or IP of rffmepg host, added to rffmpeg database on first run only
      - FFMPEG_PATH= # Optional, defaults to /usr/local/bin/wol_rffmpeg/ffmpeg - rffmpeg with optional WOL support. Can be set to /usr/local/bin/ffmpeg to bypass WOL wrapper and use rffmpeg directly.
      
      ## For WOL support use either WOL API or WOL Native

      ## WOL API settings
      #- RFFMPEG_HOST_MAC="12:ab:34:cd:ef:56" # Optional - Used for WOL.Transcode server mac enclosed in " " eg "aa:12:34:bb:cc:56"
      #- WOL_WAIT=10  # Optional - time transcode host takes to start in seconds (defaults to 30 if not set)
      #- RFFMPEG_WOL=api # Optional - set api to use wol_api container
      #- WOL_API=192.168.1.5  # Optional - WOL docker host IP
      #- WOL_API_PORT=8431  #  Optional - port wol_api is running on

      ## WOL Native setting
      #- RFFMPEG_HOST_MAC="12:ab:34:cd:ef:56" # Optional - Used for WOL.Transcode server mac enclosed in " " eg "aa:12:34:bb:cc:56"
      #- WOL_WAIT=10  # Optional - time transcode host takes to start in seconds (defaults to 30 if not set)
      #- RFFMPEG_WOL=native # Optional - set to native for inbuilt WOL support within this container
      #- WOL_NATIVE_HOST # Optional - IP of NAT gateway with forwarded port for WoL. Only applicable when not using the WoL docker service API and when waking from outside NAT is required. Omit, or leave blank otherwise.
      #- WOL_NATIVE_PORT # Optional - External port on gateway for forwarding. Ensure that it is mapped to your target machine IP on port 9. Only applicable when not using the WoL docker service API and when waking from outside NAT is required. Omit, or leave blank otherwise.
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
  wol_api:  # Optional WOL API container
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

WOL Support
Native WOL support is available if you are running in Jellyfin in host network mode. If not you can use the WOL_API container https://hub.docker.com/r/rix1337/docker-wol_api. Note the image name is rix1337/docker-wol_api