# nvm - Docker mod for code-server and openvscode-server

This mod adds nvm dev environment to code-server/openvscode-server, to be installed/updated during container start.

In code-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-nvm`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-nvm|linuxserver/mods:code-server-mod2`