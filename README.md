# Julia - Docker mod for code-server/openvscode-server

This mod adds a Julia dev environment to code-server/openvscode-server, to be installed/updated during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-julia`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-julia|linuxserver/mods:code-server-mod2`

By default, the latest stable version of Julia will be installed. If you'd like to install a different version, you can specify the version as a tag, from a list of published tags: https://hub.docker.com/r/linuxserver/mods/tags?page=1&name=code-server-julia (ie. `DOCKER_MODS=linuxserver/mods:code-server-julia-1.7.2`).
