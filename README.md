# Auto-proxy - Docker mod for SWAG

This mod gives SWAG the ability to auto-detect running containers via labels and automatically enable reverse proxy for them.

## Requirements:
- This mod needs either mapping `docker.sock` or setting the environment variable `DOCKER_HOST=remoteaddress` (see section below for [security consideration](#security-consideration)).
- Other containers to be auto-detected and reverse proxied should be in the same [user defined bridge network](https://docs.linuxserver.io/general/swag#docker-networking) as SWAG.
- Containers to be auto-detected and reverse proxied must have a label `swag=enable` at a minimum.
- To benefit from curated preset proxy confs we provide, either the container name must match the container names that are suggested in our readme examples (ie. `radarr` and not `Radarr-4K`), or the `swag_preset_conf` label must be set.

## Labels:
- `swag=enable` - required for auto-detection
- `swag_address=containername` - *optional* - overrides upstream app address. Can be set to an IP or a DNS hostname. Defaults to `container name`.
- `swag_port=80` - *optional* - overrides *internal* exposed port (if no preset conf and this label not set, auto-proxy will default to first detected exposed port)
- `swag_proto=http` - *optional* - overrides internal proto (defaults to http)
- `swag_url=containername.domain.com` - *optional* - overrides *server_name* (defaults to `containername.*`)
- `swag_auth=authelia` - *optional* - enables auth methods (options are `authelia`, `authentik`, `ldap`, `tinyauth` and `http` for basic http auth)
- `swag_auth_bypass=/api,/othersubfolder` - *optional* - bypasses auth for selected subfolders. Comma separated, no spaces.
- `swag_server_custom_directive=custom_directive;` - *optional* - injects the label value as is into the server block of the generated conf. Must be a valid nginx directive, ending with a semi colon.
- `swag_location_custom_directive=custom_directive;` - *optional* - injects the label value as is into each location block of the generated conf. Must be a valid nginx directive, ending with a semi colon.
- `swag_preset_conf=confname` - *optional* - allows defining a preset conf to use if the container name does not match one (if the conf name is `radarr.subdomain.conf.sample`, set this value to `radarr`). If the container name matches an existing conf, this var will be ignored.


In SWAG docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-auto-proxy` and either add a volume mapping for `/var/run/docker.sock:/var/run/docker.sock:ro`, or set an environment var `DOCKER_HOST=remoteaddress`.

## Security Consideration:
Mapping the `docker.sock`, especially in a publicly accessible container is a security liability. Since this mod only needs read-only access to the docker api, the recommended method is to proxy the `docker.sock` via a solution like [our docker socket proxy](https://github.com/linuxserver/docker-socket-proxy), limit the access, and set `DOCKER_HOST=` to point to the proxy address.

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
Then the env var in SWAG can be set as `DOCKER_HOST=dockerproxy`. This will allow docker cli in SWAG to be able to retrieve info on other containers, but it won't be allowed to spin up new containers.
