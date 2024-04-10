# Docker - Docker mod for all images

This mod adds the `docker` binary as wells as the `buildx` and the `compose` plug-ins to any linuxserver image.

**IMPORTANT NOTE**: For docker access inside a container, a volume mapping needs to be added for `/var/run/docker.sock:/var/run/docker.sock:ro` in the container's docker run/create/compose. If you'd like to connect to a remote docker service instead, you don't have to map the docker sock; you can either set an env var for `DOCKER_HOST=remoteaddress` or use the docker cli option `-H`.

In the container's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-docker` to enable.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-docker|linuxserver/mods:universal-mod2`

## Security consideration:

Mapping `docker.sock` is a potential security liability because docker has root access on the host and any process that has full access to `docker.sock` would also have root access on the host. Docker api has no built-in way to set limitations on access, however you can use a proxy for the `docker.sock` via a solution like [our docker socket proxy](https://github.com/linuxserver/docker-socket-proxy), which adds the ability to limit access. Then you would just set `DOCKER_HOST=` environment variable to point to the proxy address.

Here's a sample compose yaml snippet for tecnativa/docker-socket-proxy:
```yaml
  dockerproxy:
    image: lscr.io/linuxserver/socket-proxy:latest
    container_name: dockerproxy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
    environment:
      - CONTAINERS=1
      - POST=0
```
The above config for instance would allow read only access to the docker api. Then the env var in the container with the docker mod can be set as `DOCKER_HOST=dockerproxy`. This will allow the container to retrieve info on other containers, but it won't be allowed to spin up new containers. With the proxy, you can fine tune the permissions very easily.
