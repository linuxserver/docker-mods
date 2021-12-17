# stdout-logs - Docker mod for any container

This mod allows any specified log files to be tailed and included in the container's STDOUT.

In any container docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-stdout-logs`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-stdout-logs|linuxserver/mods:universal-mod2`

Simply set the environment variable `LOGS_TO_STDOUT` with a pipe-delimited (`|`) list of log files to include, such as `LOGS_TO_STDOUT="/config/logs/radarr.txt|/config/logs/radarr.debug.txt"`.
