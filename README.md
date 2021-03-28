# jellyfin-amd - Docker mode for Jellyfin

This mode adds the mesa libraries (v20.1+) needed for hardware encoding (VAAPI) on AMD GPUs to the Jellyfin Docker container.

## Docker compose
The docker-compose file needs a `devices` entry for jellyfin ([Official Documentation](https://jellyfin.org/docs/general/administration/hardware-acceleration.html))
```
---
version: "2.1"
services:
  jellyfin:
    image: linuxserver/jellyfin
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - UMASK=<022> #optional
      - DOCKER_MODS=pascalminder/jellyfin-amd:jellyfin-amd
    volumes:
      - /path/to/library:/config
      - /path/to/tvseries:/data/tvshows
      - /path/to/movies:/data/movies
      - /opt/vc/lib:/opt/vc/lib #optional
    ports:
      - 8096:8096
      - 8920:8920 #optional
      - 7359:7359/udp #optional
      - 1900:1900/udp #optional
    devices:
      # VAAPI Devices
      - "/dev/dri/renderD128:/dev/dri/renderD128"
      - "/dev/dri/card0:/dev/dri/card0"
    restart: unless-stopped
```

## Docker cli
```
docker run -d \
  --name=jellyfin \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -e UMASK=<022> `#optional` \
  -e DOCKER_MODS=pascalminder/jellyfin-amd:jellyfin-amd
  -p 8096:8096 \
  -p 8920:8920 `#optional` \
  -p 7359:7359/udp `#optional` \
  -p 1900:1900/udp `#optional` \
  -v /path/to/library:/config \
  -v /path/to/tvseries:/data/tvshows \
  -v /path/to/movies:/data/movies \
  -v /opt/vc/lib:/opt/vc/lib `#optional` \
  --device /dev/dri/renderD128:/dev/dri/renderD128 \
  --device /dev/dri/card0:/dev/dri/card0 \
  --restart unless-stopped \
  linuxserver/jellyfin
```

## Settings in Jellyfin
Under server administration in `Server > Playback` the `Hardware acceleration` can be set to `Video Acceleration API (VAAPI)` and the `VA API Device` has to be set to the device given in the Docker configuration. For example `/dev/dri/renderD128`.
