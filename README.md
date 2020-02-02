# Docker mod for openssh-server

This mod adds rsync to openssh-server, to be installed/updated during container start.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:openssh-server-rsync`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:openssh-server-rsync|linuxserver/mods:openssh-server-mod2`