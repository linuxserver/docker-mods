# Imagemagick - Docker mod for nginx/swag

This mod adds imagemagick and the php imagick module to nginx/swag, to be installed/updated during container start.

In nginx/swag docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-imagemagick`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-imagemagick|linuxserver/mods:swag-mod2`
