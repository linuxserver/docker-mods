# PHP-PPA - Docker mod for code-server and openvscode-server

This mod adds [Ondrej's PHP PPA](https://launchpad.net/~ondrej/+archive/ubuntu/php/+index) and the php and composer packages to code-server/openvscode-server, to be installed/updated during container start.

To enable, in code-server/openvscode-server docker arguments, set the following environment variables:
- `DOCKER_MODS=linuxserver/mods:code-server-php-ppa` required for enabling
- `PHP_MOD_VERSION=` optional, defaults to `8.3`, accepts versions in ppa package names
- `PHP_MOD_EXTRA_PACKAGES=` optional, accepts additional package names from the ppa, separated by `|`, no spaces

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-php-ppa|linuxserver/mods:code-server-mod2`
