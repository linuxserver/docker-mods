# VueTorrent WebUi - Docker mod for qBittorrent

This mod adds [VueTorrent](https://github.com/WDaan/VueTorrent), to be installed to [qBittorrent](https://github.com/linuxserver/docker-qbittorrent/) during container start.

In qBittorrent docker arguments, set an environment variable `DOCKER_MODS=bricksoft/qbittorrent-vuetorrent` to enable.

If adding multiple mods, enter them in an array separated by `|`, such as 
> `DOCKER_MODS=bricksoft/qbittorrent-vuetorrent|linuxserver/mods:other-mod`