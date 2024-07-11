# Redis - Docker mod for any container

This mod adds redis to any container, to be installed/updated during container start.

In the docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-redis`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-redis|linuxserver/mods:openssh-server-mod2`
