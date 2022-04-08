# **DEPRECATED**

This mod has been deprecated and will not receive future updates. Please use the universal version instead:

`linuxserver/mods:universal-docker`

# Docker - Docker mod for code-server

This mod adds docker and docker-compose binaries to code-server.

**IMPORTANT NOTE**: For docker access inside code-server, a volume mapping needs to be added for `/var/run/docker.sock:/var/run/docker.sock` in code-server docker run/create/compose. If you'd like to connect to a remote docker service instead, you don't have to map the docker sock; you can either set an env var for `DOCKER_HOST=remoteaddress` or use the docker cli option `-H`.

In code-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-docker` to enable.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-docker|linuxserver/mods:code-server-mod2`
