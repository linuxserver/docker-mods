# nvm - Docker mod for code-server and openvscode-server

This mod adds [Node Version Manager](https://github.com/nvm-sh/nvm) to [linuxserver/code-server](https://github.com/linuxserver/docker-code-server) and [linuxserver/openvscode-server](https://github.com/linuxserver/docker-openvscode-server), to be installed during container start.

In the docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-nvm`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-nvm|linuxserver/mods:code-server-mod2`
