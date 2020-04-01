# SSH-Tunnel - Docker mod for openssh-server

This mod adds ssh tunnelling to openssh-server, by enabling tcp forwarding during container start.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:openssh-server-ssh-tunnel`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:openssh-server-ssh-tunnel|linuxserver/mods:openssh-server-mod2`

Note: `GatewayPorts` is set to `clientspecified`, this moves the responsibility to define the gateway host of the port to the client that opens the tunnel, e.g. `*:8080` to forward 8080 to all connection, default is localhost only.
In addition it is still necessary to expose the same port on the container level, using either the `--expose` (only to other containers) or the `--port` (expose on host level/internet) run options (or the counterparts in docker-compose).

Example:

When creating the container with the following setup:
```
version: '2'
services:
  openssh-server:
    image: linuxserver/openssh-server
    environment:
      - DOCKER_MODS=linuxserver/mods:openssh-server-ssh-tunnel
    volumes:
      - /path/to/appdata/config:/config
    expose:
      - 30000
    ports:
      - 2222:2222
```

It's possible to expose the client's port 8080 through the container's port 30000 like this:
```
ssh -R *:30000:localhost:8080 example.com -p 2222
```

Port 30000 will then only be available to other containers (e.g. a web server acting as a reverse proxy). When using `ports` instead of `expose` the port would be accessible from the host (and the network it resides in, e.g. the internet). The client command can be automated using autossh.
