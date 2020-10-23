# Docker - Docker mod for all images

This mod adds `docker` and `docker-compose` binaries to any linuxserver image.

**IMPORTANT NOTE**: For docker access inside a container, a volume mapping needs to be added for `/var/run/docker.sock:/var/run/docker.sock` in the container's docker run/create/compose. If you'd like to connect to a remote docker service instead, you don't have to map the docker sock; you can either set an env var for `DOCKER_HOST=remoteaddress` or use the docker cli option `-H`.

In the container's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-docker` to enable.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-docker|linuxserver/mods:universal-mod2`
