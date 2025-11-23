# On-demand - Docker mod for SWAG

This mod gives SWAG the ability to start containers on-demand when accessed through SWAG and stop them after a period of inactivity. It takes a few seconds for containers to start on-demand, you'll need to refresh the tab or add a loading page as detailed below.

## Setup:
- In SWAG's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-ondemand` and either add a volume mapping for `/var/run/docker.sock:/var/run/docker.sock:ro`, or set an environment var `DOCKER_HOST=remoteaddress` (read the security considerations below).
- Add the label `swag_ondemand=enable` to on-demand containers.
    ```yaml
    somecontainer:
        container_name: somecontainer
        ...
        labels:
            - swag_ondemand=enable
    ```
- Replace the following line in `/config/nginx/nginx.conf`:
    ```nginx
    access_log /config/log/nginx/access.log;
    ```
    With:
    ```nginx
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request_method $scheme://$host$request_uri $server_protocol" '
                    '$status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent"';
    access_log /config/log/nginx/access.log main;
    ```
- *Optional* - In SWAG's docker arguments, set an environment variable `SWAG_ONDEMAND_STOP_THRESHOLD` to override the period of inactivity in seconds before stopping the container. Defaults to `600` which is 10 minutes.
    ```yaml
    swag:
        container_name: swag
        ...
        environment:
            - SWAG_ONDEMAND_STOP_THRESHOLD=600
    ```
### Loading Page:

![loading-page](.assets/loading-page.png)

Instead of showing a 502 error page, it can display a loading page and auto-refresh once the container is up.
  
Add the following `include` to each proxy-conf where you wish to show the loading page inside the `server` section:
```nginx
server {
    ...
    include /config/nginx/ondemand.conf;
    ...
```
Or set the following label if using `swag-auto-proxy`:
```yaml
    somecontainer:
        container_name: somecontainer
        ...
        labels:
            - swag_server_custom_directive=include /config/nginx/ondemand.conf;
```
### Labels:
- `swag_ondemand=enable` - required for on-demand.
- `swag_ondemand_urls=https://wake.domain.com,https://app.domain.com/up` - *optional* - overrides the monitored URLs for starting the container on-demand. Defaults to `https://somecontainer.,http://somecontainer.`.

### URLs:
- Accessed URLs need to start with one of `swag_ondemand_urls` to be matched, for example, setting `swag_ondemand_urls=https://plex.` will apply to `https://plex.domain.com` and `https://plex.domain.com/something`.
- `swag_ondemand_urls` default to `https://somecontainer.,http://somecontainer.`, for example `https://plex.,http://plex.`.
- `swag_ondemand_urls` don't need to be valid, it will work as long as it reaches swag and gets logged by nginx under `/config/log/nginx/access.log`.
- The same URL can be set on multiple containers and all of them will be started when accessing that URL.

### Logging:
The log file can be found under `/config/log/ondemand/ondemand.log`.

## Security Consideration:
Mapping the `docker.sock`, especially in a publicly accessible container is a security liability. Since this mod only needs read-only access to the docker api, the recommended method is to proxy the `docker.sock` via a solution like [our docker socket proxy](https://github.com/linuxserver/docker-socket-proxy), limit the access, and set `DOCKER_HOST=` to point to the proxy address.

Here's a sample compose yaml snippet for `linuxserver/docker-socket-proxy`:
```yaml
  socket-proxy:
    image: lscr.io/linuxserver/socket-proxy:latest
    container_name: socket-proxy
    environment:
      - ALLOW_START=1
      - ALLOW_STOP=1
      - CONTAINERS=1
      - POST=0
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /run
```
Then the env var in SWAG can be set as `DOCKER_HOST=tcp://socket-proxy:2375`. This will allow docker in SWAG to be able to start/stop existing containers, but it won't be allowed to spin up new containers.
