# Memories - Docker mod for nextcloud

This mod adds the required packages the [Memories](https://apps.nextcloud.com/apps/memories) nextcloud app needs to work.

In nextcloud docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:nextcloud-memories`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:nextcloud-memories|linuxserver/mods:nextcloud-mod2`
