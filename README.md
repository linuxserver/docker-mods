# nextcloud-notify-push - Docker mod for Nextcloud  

This mod adds a service to start the [notify-push](https://github.com/nextcloud/notify_push) binary.

## Requirements

- Redis configured in your config.php

## Setup

1. Add ``DOCKER_MODS=linuxserver/mods:nextcloud-notify-push`` to your env.

2. Make sure that Redis is already configured with Nextcloud.

3. notify_push should be running and ``**** Starting notify-push ****`` appear in the log. Also check for errors.

### Reverse Proxy

The reverse proxy of the `notify_push` service at subfolder `/push` is handled within the Nextcloud container's Nginx site conf. Make sure you are on the latest version. If not sure, make sure your Nextcloud container is up to date, then you can delete the existing site conf at `/config/nginx/site-confs/default.conf` and restart the container. A new conf with the reverse proxy support will be created.

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
