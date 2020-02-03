# Docker mod for openssh-server

This mod adds openssh-client to openssh-server, to be installed/updated during container start.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:openssh-server-openssh-client`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:openssh-server-openssh-client|linuxserver/mods:openssh-server-mod2`