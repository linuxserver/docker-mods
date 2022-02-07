# CrowdSec - Docker mod for SWAG

This mod adds the CrowdSec nginx bouncer to SWAG, to be installed/updated during container start.

In SWAG docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-crowdsec`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-crowdsec|linuxserver/mods:swag-dbip`

## Mod usage instructions

If running CrowdSec in a container it must be on a common docker network with SWAG.

Generate an API key for the bouncer with `cscli bouncers add bouncer-nginx` or `docker exec -t crowdsec cscli bouncers add bouncer-nginx`, if you're running CrowdSec in a container.

Make a note of the API key as you can't retrieve it later without removing and re-adding the bouncer.

Set the following environment variables on your SWAG container.

| | | |
| --- | --- | --- |
| `CROWDSEC_API_KEY` | **Required** | Your bouncer API key |
| `CROWDSEC_LAPI_URL` | **Required** | Your local CrowdSec API endpoint, for example `http://crowdsec:8080` |
| `CROWDSEC_SITE_KEY` | **Optional** | reCAPTCHA v2 Site Key |
| `CROWDSEC_SECRET_KEY` | **Optional** | reCAPTCHA v2 Secret Key |
| | | |

The variables need to remain in place while you are using the mod. If you remove **required** variables the bouncer will be disabled the next time you recreate the container, if you remove **optional** variables the associated features will be disabled the next time you recreate the container.

## Mod uninstall instructions

Delete `/config/nginx/crowdsec_nginx.conf`

In `/config/nginx/nginx.conf` remove the following lines

```nginx
    #Include CrowdSec Bouncer
    include /config/nginx/crowdsec_nginx.conf;
```
