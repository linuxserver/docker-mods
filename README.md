# DEPRECATED, Please switch to the [PHP_PPA mod](https://github.com/linuxserver/docker-mods/tree/code-server-php-ppa)
# PHP8 - Docker mod for code-server/openvscode-server

This mod adds php8.2 and composer to code-server/openvscode-server, to be installed/updated during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-php8`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-php8|linuxserver/mods:code-server-mod2`
