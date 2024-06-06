# nvm - Docker mod for code-server

This mod adds [PNPM](https://github.com/pnpm/pnpm) dev environment to linuxserver/code-server, to be installed or updated during container start.

In code-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-pnpm`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-pnpm|linuxserver/mods:code-server-mod2`