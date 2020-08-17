# mysqldump-cron - Docker mod for mariadb

This mod adds cron schedules that run mysqldump on mariadb. The default will create daily backups of all databases with 7 day rotation and weekly backups with 4 week rotation. You can edit `/config/crontabs/mysqldump` to change the schedules, but the file cannot be renamed.

In mariadb docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:mariadb-mysqldump-cron`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:mariadb-mysqldump-cron|linuxserver/mods:mariadb-mod2`
