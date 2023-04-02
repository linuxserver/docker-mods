# CrowdSec - Docker mod for SWAG

## nginx.conf change

Make sure that the line below, under virtual hosts, is in your nginx.conf, otherwise crowdsec-bouncer will not work. More information here https://info.linuxserver.io/issues/2022-08-20-nginx-base/

    # Includes virtual hosts configs.
    include /etc/nginx/http.d/*.conf;

This mod adds the [CrowdSec](https://crowdsec.net) [nginx bouncer](https://github.com/crowdsecurity/cs-nginx-bouncer/) to SWAG, to be installed/updated during container start.

In SWAG docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-crowdsec`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-crowdsec|linuxserver/mods:swag-dbip`

## Mod usage instructions

If running CrowdSec in a container it must be on a common docker network with SWAG.

Generate an API key for the bouncer with `cscli bouncers add bouncer-swag` or `docker exec -t crowdsec cscli bouncers add bouncer-swag`, if you're running CrowdSec in a container.

Make a note of the API key as you can't retrieve it later without removing and re-adding the bouncer.

Set the following environment variables on your SWAG container.

| | | |
| --- | --- | --- |
| `CROWDSEC_API_KEY` | **Required** | Your bouncer API key |
| `CROWDSEC_LAPI_URL` | **Required** | Your local CrowdSec API endpoint, for example `http://crowdsec:8080` |
| `CROWDSEC_SITE_KEY` | **Optional** | CAPTCHA Site Key |
| `CROWDSEC_SECRET_KEY` | **Optional** | CAPTCHA Secret Key |
| `CROWDSEC_CAPTCHA_PROVIDER` | **Optional** | CAPTCHA Provider (currently supported providers are `recaptcha`, `hcaptcha`, `turnstile`), requires v1.0.5 or newer. |
| `CROWDSEC_VERSION` | **Optional** | Specify a version of the bouncer to install instead of using the latest release, for example `v1.0.0`. Must be a valid [release tag](https://github.com/crowdsecurity/cs-nginx-bouncer/tags). **Does not support versions older than v1.0.0**.
| `CROWDSEC_F2B_DISABLE` | **Optional** | Set to `true` to disable swag's built-in fail2ban service if you don't need it |
| `CROWDSEC_MODE` | **Optional** | Set to `live` (immediate update) or `stream` to update requests every CROWDSEC_UPDATE_FREQUENCY seconds. Defaults to `live` |
| `CROWDSEC_UPDATE_FREQUENCY` | **Optional** | Set update frequency for use with `stream` mode. Defaults to `10`. |
| | | |

The variables need to remain in place while you are using the mod. If you remove **required** variables the bouncer will be disabled the next time you recreate the container, if you remove **optional** variables the associated features will be disabled the next time you recreate the container.

### reCAPTCHA Support Notes

If you're using the reCAPTCHA capability and you're running in an IPv4-only environment then you need to edit your `/config/nginx/resolver.conf` and add `ipv6=off` to the end of the `resolver` statement otherwise the bouncer will attempt to contact the reCAPTCHA endpoint over IPv6 and fail.

e.g. `resolver  127.0.0.11 valid=30s ipv6=off;`

## Versions

* **29.03.23:** - Support multiple captcha providers from upstream.
* **28.01.23:** - Support mode selection, handle s6v3 init.
* **25.08.22:** - Make hybrid mod.
* **14.03.22:** - Initial Release.
