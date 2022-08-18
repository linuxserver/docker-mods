# Julia - Docker mod for code-server/openvscode-server

This mod adds a Julia dev environment to code-server/openvscode-server, to be installed/updated during container start.

**This mod no longer supports arm32v7 due to upstream binaries no longer guaranteed to be available on it per [this post](https://discourse.julialang.org/t/is-the-linux-armv7l-binary-deprecated/85924/2).**

In code-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-julia`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-julia|linuxserver/mods:code-server-mod2`

By default, the latest stable version of Julia will be installed. If you'd like to install a different version, you can specify the version as a tag, from a list of published tags: https://hub.docker.com/r/linuxserver/mods/tags?page=1&name=code-server-julia (ie. `DOCKER_MODS=linuxserver/mods:code-server-julia-1.8.0`).
