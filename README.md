# pnpm - Docker mod for code-server

This mod adds [PNPM](https://github.com/pnpm/pnpm) to [linuxserver/code-server](https://github.com/linuxserver/docker-code-server), to be installed during container start.

In the docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-pnpm`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-pnpm|linuxserver/mods:code-server-mod2`
