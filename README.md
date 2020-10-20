# Prolog - Docker mod for code-server

This mod adds `prolog` to code-server, to be installed/updated during container start.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-prolog`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-prolog|linuxserver/mods:code-server-java`

