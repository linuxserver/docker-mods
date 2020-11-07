# mariadb - Docker mod for mariadb-maria-backup

This mod adds maria-backup to mariadb, to be installed/updated during container start.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:mariadb-maria-backup`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:mariadb-maria-backup|linuxserver/mods:mariadb-mod2`
