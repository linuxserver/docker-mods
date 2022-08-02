# Java11 - Docker mod for code-server and openvscode-server

This mod adds a java11 dev environment to code-server and openvscode-server, to be installed/updated during container start.

In code-server or openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-java11`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-java11|linuxserver/mods:code-server-mod2`
