# THIS MOD HAS BEEN DEPRECATED - Please use [swag-imagemagick](https://github.com/linuxserver/docker-mods/tree/swag-imagemagick) instead

# Imagemagick - Docker mod for nginx/letsencrypt

This mod adds imagemagick and the php7 imagick module to nginx/letsencrypt, to be installed/updated during container start.

In nginx/letsencrypt docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:letsencrypt-imagemagick`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:letsencrypt-imagemagick|linuxserver/mods:letsencrypt-mod2`
