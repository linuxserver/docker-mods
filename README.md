# VueTorrent WebUi - Docker mod for qBittorrent

This mod adds [VueTorrent](https://github.com/WDaan/VueTorrent), to be installed to [qBittorrent](https://github.com/linuxserver/docker-qbittorrent/) during container start. 

Also this script automatically updates `vuetorrent` every time you restart your container.

In qBittorrent docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:qbittorrent-vuetorrent` to enable.

If adding multiple mods, enter them in an array separated by `|`, such as 
> `DOCKER_MODS=linuxserver/mods:qbittorrent-vuetorrent|linuxserver/mods:other-mod`
