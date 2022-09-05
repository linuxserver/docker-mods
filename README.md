# AWSCLI - Docker mod for code-server/openvscode-server

This mod adds AWSCLI to code-server/openvscode-server, to be installed/updated during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-awscli`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-awscli|linuxserver/mods:code-server-mod2`
