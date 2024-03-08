# unrar6 - Docker mod for any container

This mod adds unrar version 6 to any container, to be installed/updated during container start.

In the docker arguments, set an environment variable `DOCKER_MODS=lscr.io/linuxserver/mods:universal-unrar6`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=lscr.io/linuxserver/mods:universal-unrar6|lscr.io/linuxserver/mods:universal-mod2`
