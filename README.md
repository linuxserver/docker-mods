# cron - Docker mod for any container

This mod adds cron to any container.

In the container docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:cron`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:cron|linuxserver/mods:other-mod`
