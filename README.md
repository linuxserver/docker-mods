# Translations - Docker mod for projectsend

This mod adds installation options for adding translations to the [Docker image of LinuxServer.io](https://github.com/linuxserver/docker-projectsend) for [ProjectSend](http://www.projectsend.org/). The translations to be installed can be defined with ``PS_INSTALL_TRANSLATIONS`` as a comma-separated list and will be automatically downloaded from the [official translations website](https://www.projectsend.org/translations/). To help translating (and adding your preferred language to) ProjectSend, please follow [this link](https://www.transifex.com/subwaydesign/projectsend/).

## Using this Docker Mod

To add this Docker Mod to your installation of the ProjectSend [Docker image of LinuxServer.io](https://github.com/linuxserver/docker-projectsend), please add this endpoint ``linuxserver/mods:projectsend-translations`` to the ``DOCKER_MODS`` environment variable. You can install multiple Docker Mods by separating them by ``|``. [Read this page](https://github.com/linuxserver/docker-mods#using-a-docker-mod) for more information.

Now, you can define the languages/translations to be installed with their "Lang. code" value from the before mentioned [official translations website](https://www.projectsend.org/translations/) to the ``TRANSLATIONS`` environment variable. You can choose to install multiple translations by separating them with commas. The English translation ``en`` is automatically installed by the ProjectSend image and does not have to be addressed by this Docker Mod or the ``TRANSLATIONS`` environment variable.

Full example with ``docker-compose``:

```
---
version: "2.1"
services:
  projectsend:
    image: lscr.io/linuxserver/projectsend
    container_name: projectsend
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - MAX_UPLOAD=<5000>
      - DOCKER_MODS=linuxserver/mods:projectsend-translations
      - TRANSLATIONS=de,fr,zh_CN
    volumes:
      - <path to data>:/config
      - <path to data>:/data
    ports:
      - 80:80
    restart: unless-stopped
```

## Source / References
I took inspiration from the Dockerfile of the [Grafana](https://github.com/grafana/grafana/) repository, especially [this file](https://github.com/grafana/grafana/blob/main/packaging/docker/run.sh). Thanks!