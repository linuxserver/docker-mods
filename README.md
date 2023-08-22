# Auto Uptime Kuma - Docker mod for SWAG

This mod gives SWAG the ability to automatically add Uptime Kuma "Monitors" for the running containers. Ultimately it will allow you with a very low effort to setup notifications whenever any of your services goes down etc.

## Requirements

Running [Uptime Kuma](https://github.com/louislam/uptime-kuma) instance with `username` and `password` configured. The container should be in the same [user defined bridge network](https://docs.linuxserver.io/general/swag#docker-networking) as SWAG.

## Installation

In SWAG docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-auto-uptime-kuma`.

Add additional environment variables to the SWAG docker image:

| Name                   | Required | Example                    | Description                                                                                                                                                                                                                       |
| ---------------------- | -------- | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `UPTIME_KUMA_URL`      | Yes      | `http://uptime-kuma:3001/` | The URL to the Uptime Kuma instance. Please note this cannot be the domain that it configured by SWAG as during initialization phase of the container those domains are not yet available. Instead use the docker container name. |
| `UPTIME_KUMA_USERNAME` | Yes      | `admin`                    | Your Uptime Kuma username                                                                                                                                                                                                         |
| `UPTIME_KUMA_PASSWORD` | Yes      | `password`                 | Your Uptime Kuma password                                                                                                                                                                                                         |

Unfortunately Uptime Kuma does not provide API keys for it's Socket.io API at the moment and Username/Password have to be used.

Finally, add `swag.uptime-kuma.enabled=true` label at minimum to each of your containers that you wish to monitor. More types of labels are listed in next section.

## Labels

This mod is utilizing the wonderful [Uptime Kuma API](https://github.com/lucasheld/uptime-kuma-api) library. It allows you configure nearly every property of the Monitors by defining Docker Labels. For detailed documentation of each of these properties please refer to the `add_monitor` endpoint in the [official documentation](https://uptime-kuma-api.readthedocs.io/en/latest/api.html#uptime_kuma_api.UptimeKumaApi.add_monitor).

| Label                                  | Default Value                                    | Example Value                                                                                                | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `swag.uptime-kuma.enabled`             | `false`                                          | `true`                                                                                                       | The only required label for the minimal setup. It allows the mod to detect the container and configure monitor.                                                                                                                                                                                                                                                                                                                                               |
| `swag.uptime-kuma.monitor.name`        | `{containerName}`                                | Radarr <br> Jellyfin Public                                                                                  | By default the name of the Monitor will be value of the Docker container name transformed to start with uppercase letter.                                                                                                                                                                                                                                                                                                                                     |
| `swag.uptime-kuma.monitor.url`         | `https://{containerName}.{domainName}`           | `https://radarr.domain.com/` <br> `https://pihole.domain.com/admin/`                                             | By default the URL of each container if build based of the actual container name (`{containerName}`) defined in docker and the value of `URL` environment variable (`{domainName}`) defined in SWAG (as required by SWAG itself).                                                                                                                                                                                                                             |
| `swag.uptime-kuma.monitor.type`        | http                                             | http                                                                                                         | While technically possible to override the monitor type the purpose of this mod is to monitor HTTP endpoints.                                                                                                                                                                                                                                                                                                                                                 |
| `swag.uptime-kuma.monitor. description` | Automatically generated by SWAG auto-uptime-kuma | My own description                                                                                           | The description is only for informational purposes and can be freely changed                                                                                                                                                                                                                                                                                                                                                                                  |
| `swag.uptime-kuma.monitor.*`           |                                                  | `swag.uptime-kuma.monitor. maxretries=5` <br> `swag.uptime-kuma.monitor. accepted_statuscodes= 200-299,404,501` | There are many more properties to configure. The fact that aything can be changed does not mean that it should. Some properties or combinations could not work and should be changed only if you know what you are doing. Please check the [Uptime Kuma API](https://uptime-kuma-api.readthedocs.io/en/latest/api.html#uptime_kuma_api.UptimeKumaApi.add_monitor) for more examples. Properties that are expected to be lists should be separated by comma `,` |

## Notifications

While ultimately this mod makes it easier to setup notifications for your docker containers it does not configure more than Uptime Kuma Monitors. In order to receive Notifications you should configure them manually and then either enable one type to be default for all your Monitors or specify the Notifications by using the `swag.uptime-kuma.monitor.notificationIDList` label.

## Known Limitations

- At the moment this mod does *NOT* monitor your docker containers for changes. This means that whenever you change any of your labels or remove a container and wish to no longer monitor it then the changes will *NOT* be applied to Uptime Kuma in real time. In order to reload the changes you have two options:
  - Restart the `swag` container. This will run initialization scripts again and reload all the changes (add/delete/update monitors)
  - Run the script manually which is the following command via `ssh`: `docker exec swag python3 /app/auto-uptime-kuma.py` (where `swag` is your container name of the SWAG instance).

- Due to limitations of the Uptime Kuma API whenever you make changes to your container or labels that already have a Monior setup then the **Update** action will be performed by running **Delete** followed by **Add**. What it means that all changes will result in a new Monitor for the same container that will lose history of the heartbeats, all manual changes and get a new 'id' number.

## Purge data

For the purpose of development or simply if you feel that you want to purge all the Monitors and files created by this mod you can run following command via `ssh`: `docker exec swag python3 /app/auto-uptime-kuma.py -purge` (where `swag` is your container name of the SWAG instance).
