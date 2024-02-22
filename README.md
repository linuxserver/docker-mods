# Docker-in-docker (dind) - Docker mod for Ubuntu and Alpine based images

This mod adds docker-in-docker (dind) to Ubuntu and Alpine based images, to be installed/updated during container start.
Main advantage is that all docker images, containers, volumes, etc. will reside inside the container and will be sandboxed from the host's docker environment.
Main disadvantage is that it requires the container to run with `privileged`.

## How to enable:
In the container's docker arguments,
* Set an environment variable `DOCKER_MODS=linuxserver/mods:universal-docker-in-docker`
* Set the `privileged` option for the container

Docker data root will reside under `/config/var/lib/docker` by default, this is configurable by setting `MODS_DIND_PERSISTENCE` to the wanted path.
On amd64, QEMU will be enabled on container start.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-docker-in-docker|linuxserver/mods:universal-mod2`
