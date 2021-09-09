# autossh - Docker mod for openssh-server

This mod adds autossh to openssh-server, to be installed/updated during container start.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:openssh-server-autossh`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:openssh-server-autossh|linuxserver/mods:openssh-server-mod2`
