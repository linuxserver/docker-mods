# Healtchecks Apprise mod layer

This is a docker mod layer adding [Apprise](https://github.com/caronc/apprise) to the [linuxserver/docker-healthchecks](https://github.com/linuxserver/docker-healthchecks) docker image.

To use this docker mod set the environment variable `DOCKER_MODS` to `linuxserver/mods:healthchecks-apprise`. If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:healtchecks-mod1|linuxserver/mods:healthcheck-apprise`.

Example with docker-compose:

```yaml
version: "2.1"
services:
  healthchecks:
    image: linuxserver/healthchecks
    container_name: healthchecks
    environment:
      - PUID=1000
      - PGID=1000
      - DOCKER_MODS=linuxserver/mods:healthchecks-apprise
      - SITE_ROOT=SITE_ROOT
      - SITE_NAME=SITE_NAME
      - DEFAULT_FROM_EMAIL=DEFAULT_FROM_EMAIL
      - EMAIL_HOST=EMAIL_HOST
      - EMAIL_PORT=EMAIL_PORT
      - EMAIL_HOST_USER=EMAIL_HOST_USER
      - EMAIL_HOST_PASSWORD=EMAIL_HOST_PASSWORD
      - EMAIL_USE_TLS=True or False
      - ALLOWED_HOSTS=ALLOWED_HOSTS
      - SUPERUSER_EMAIL=SUPERUSER_EMAIL
      - SUPERUSER_PASSWORD=SUPERUSER_PASSWORD
    volumes:
      - /path/to/data/on/host:/config
    ports:
      - 8000:8000
    restart: unless-stopped
```

Note that you will also have to enable Apprise in the [Healthchecks](https://github.com/healthchecks/healthchecks#apprise) application. To do so add the following line to the file `local_settings.py`:

```python
APPRISE_ENABLED=True
```
