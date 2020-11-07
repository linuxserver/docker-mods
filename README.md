# mariadb-backup - Docker mod for mariadb

This mod adds mariadb-backup to mariadb, to be installed/updated during container start.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:mariadb-mariadb-backup`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:mariadb-mariadb-backup|linuxserver/mods:mariadb-mod2`
