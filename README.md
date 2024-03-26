# nextcloud-notify-push - Docker mod for Nextcloud  

This mod adds a service to start the [notify-push](https://github.com/nextcloud/notify_push) binary.

## Requirements

- Redis configured in your config.php

## Setup

1. Add ``DOCKER_MODS=linuxserver/mods:nextcloud-notify-push`` to your env.

2. Make sure that Redis is already configured with Nextcloud.

3. [Configure your reverse proxy for notify push.](https://github.com/nextcloud/notify_push#reverse-proxy)

4. notify_push should be running and ``**** Starting notify-push ****`` appear in the log. Also check for errors.

### SWAG configuration

SWAG's preset proxy conf for Nextcloud has been updated to support this mod out of the box. Make sure you are using the updated conf (to update an existing one, you can simply delete your existing conf, rename the sample to `nextcloud.subdomain.conf` and restart SWAG).

### Traefik configuration

notify-push listens on its own port, therefore we need to to forward all traffic under example.org/push/* to port 7867.

We need to add an additional router and service to the container. Having more than one router requires to explicitly configure more options. Additionally a new middleware to strip the /push prefix.

Replace "*cloud.example.org*" for both routers with your domain!

#### Before

```yaml
    ...
    labels:
        - "traefik.enable=true"
        - "traefik.http.routers.nextcloud.entryPoints=https"
        - "traefik.http.routers.nextcloud.rule=Host(`cloud.example.org`)"
        - "traefik.http.services.nextcloud.loadbalancer.server.port=443"
```

#### After

```yaml
    ...
    labels:
        # Nextcloud
        - "traefik.enable=true"
        - "traefik.http.routers.nextcloud.entryPoints=https"
        - "traefik.http.routers.nextcloud.rule=Host(`cloud.example.org`)"
        - "traefik.http.services.nextcloud.loadbalancer.server.port=443"
        # add service
        - "traefik.http.routers.nextcloud.service=nextcloud"

        #Notify-push
        # forward cloud.example.org/push/*
        - "traefik.http.routers.nextcloud_push.rule=Host(`cloud.example.org`) && PathPrefix(`/push`)"
        # entry point
        - "traefik.http.routers.nextcloud_push.entryPoints=https"
        # set protocol to http
        - "traefik.http.services.nextcloud_push.loadbalancer.server.scheme=http"
        # set port
        - "traefik.http.services.nextcloud_push.loadbalancer.server.port=7867"
        # use middleware
        - "traefik.http.routers.nextcloud_push.middlewares=nextcloud_strip_push"
        # define middleware
        - "traefik.http.middlewares.nextcloud_strip_push.stripprefix.prefixes=/push"
        # add service
        - "traefik.http.routers.nextcloud_push.service=nextcloud_push"

```

## Validation

1. Read the section about the [Test client](https://github.com/nextcloud/notify_push#test-client). Create an app password and connect to your server

    ```sh
    test_client https://cloud.example.com username password
    ```

2. Run ``occ notify_push:metrics``. Step 1 can be skipped if real clients are already connected.

    ```sh
    root@1d0f9bf7fff9:/# occ notify_push:metrics
    Active connection count: 2
    Active user count: 1
    Total connection count: 5
    Total database query count: 1
    Events received: 13
    Messages sent: 3
    ```
