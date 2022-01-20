# Cloudflared - Universal docker mod

In docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-cloudflared`

If no additional parameters are supplied this mod adds [`cloudflared`](https://github.com/cloudflare/cloudflared) using the [latest release tag](https://github.com/cloudflare/cloudflared/releases/latest) to any [LSIO docker image](https://fleet.linuxserver.io/), to be installed/updated during container start.

If all additional parameters are supplied this docker mod will also create/configure/route/enable a cloudflare tunnel via `cloudflared` and the cloudflare v4 API.

## Usage

Here an example snippet to help you get started using this docker mod.

### docker-compose ([recommended](https://docs.linuxserver.io/general/docker-compose))

```yaml
  swag:
    image: ghcr.io/linuxserver/swag
    container_name: swag
    cap_add:
      - NET_ADMIN
    environment:
      PUID: 1000
      PGID: 1000
      TZ: Europe/London
      URL: yourdomain.url
      SUBDOMAINS: test,
      VALIDATION: dns
      DNSPLUGIN: cloudflare #optional
      ONLY_SUBDOMAINS: true #optional
      EMAIL: #optional
      EXTRA_DOMAINS: #optional
      STAGING: false #optional
      DOCKER_MODS: linuxserver/mods:universal-cloudflared
      CF_ZONE_ID: #optional
      CF_ACCOUNT_ID: #optional
      CF_API_TOKEN: #optional
      CF_TUNNEL_NAME: example #optional
      CF_TUNNEL_PASSWORD: pleasedontusethisexamplepassword #optional
      CF_TUNNEL_CONFIG: | #optional
        ingress:
          - hostname: test.yourdomain.url
            service: hello_world
          - service: http_status:404
    volumes:
      - /path/to/appdata/config:/config
    restart: unless-stopped
```

## Parameters

Container images/mods are configured using parameters passed at runtime (such as those above).

| Parameter | Function | Notes |
| :----: | --- | --- |
| `DOCKER_MODS` | Enabled this docker mod with `linuxserver/mods:universal-cloudflared` | If adding multiple mods, enter them in an array separated by `\|`, such as `DOCKER_MODS: linuxserver/mods:universal-cloudflared\|linuxserver/mods:universal-mod2` |

### Optional tunnel parameters

| Parameter | Function | Notes |
| :----: | --- | --- |
| `CF_ZONE_ID` | Cloudflare zone ID |   |
| `CF_ACCOUNT_ID` | Cloudflare account ID |   |
| `CF_API_TOKEN` | Cloudflare API token | Must have the `Account.Argo Tunnel:Edit` and `Zone.DNS:Edit` permissions. |
| `CF_TUNNEL_NAME` | Cloudflare tunnel name |   |
| `CF_TUNNEL_PASSWORD` | Cloudflare tunnel password | 32 char minimum |
| `CF_TUNNEL_CONFIG` | Cloudflare tunnel config, please refer to cloudflares official tunnel docs. | Do not add `tunnel`/`credentials-file` headers, these are handled automatically. |
| `FILE__<VARIABLE_NAME>`| Sources content of the file as value in case of multiline content | `FILE__CF_TUNNEL_CONFIG=/config/tunnelconfig.yml` |

---

### Unraid / Synology / Qnap / WebGUI

You can optionally use function of setting a file content as a environment variable if you are not using docker directly, cannot use docker-compose or have to define multiline environment variables inside a webGUI or similar.

You can include the content of `CF_TUNNEL_CONFIG` for example, which contains multiline content

```yaml
      CF_TUNNEL_CONFIG: | #optional
        ingress:
          - hostname: test.yourdomain.url
            service: hello_world
          - service: http_status:404
```

Create a yaml file in directory where you mounted `/config` folder of your container. It still has to ba a valid yaml file.

```shell
# cat /config/tunnelconfig.yml
ingress:
  - hostname: test.yourdomain.url
    service: hello_world
  - service: http_status:404
```

After you have created the file, use special `FILE__` prefix for the environmet variable which will source the content of the file as a value for the variable specified after `FILE__`

#### Troubleshting

If you are getting error `Json deserialize error: control character (\\u0000-\\u001F) found while parsing`, please make sure when copy/pasting environment varibales and their value from web sources that they do not contain new line characters.
