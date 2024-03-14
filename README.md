# PHP-CLI - Docker mod for code-server/openvscode-server

This mod adds php-cli and composer to code-server/openvscode-server, to be installed/updated during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-php-cli`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-php-cli|linuxserver/mods:code-server-mod2`

## Installing specific PHP version

To install a specific PHP version simply define the environment variable `PHP_VERSION` with the version of your choice. As this mod uses the `ondrej/php` repository you can choose from the available versions there.

As default this mod will install PHP 8.2.

Example: `PHP_VERSION=8.1`

__WARNING__\
Composer requires at least PHP 7.4 to run!

## Installing PHP extensions

To install PHP extensions simply define the environment variable `PHP_EXTENSIONS`. If you want to install multiple extensions, seperate them with `|`.

Example: `PHP_EXTENSIONS=simplexml|gd|zip`

## Enable Composer binary

To enable the installation of the `composer` binary, set the environment variable `ENABLE_COMPOSER` to `yes`.

Example: `ENABLE_COMPOSER=yes`

__WARNING__\
Composer requires at least PHP 7.4 to run!

## PHP configuration files

You can find all the PHP configuration files at `/config/.php`.
They are symlinked to `/etc/php`