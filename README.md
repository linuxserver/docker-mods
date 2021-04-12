# Ioncube Loader - Docker mod for SWAG/nginx

This mod adds Ioncube loader to SWAG/nginx, to be installed/updated during container start.

In SWAG/nginx docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-ioncube`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-ioncube|linuxserver/mods:swag-auto-reload`
