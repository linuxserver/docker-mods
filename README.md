# Nodejs - Docker mod for code-server/openvscode-server

This mod adds a nodejs dev environment to code-server/openvscode-server, to be installed/updated during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-nodejs`

You can define the nodejs major version to be installed via setting the environment variable `NODEJS_MOD_VERSION` (accepts `16`, `18`, etc. defaults to `14`).

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-nodejs|linuxserver/mods:code-server-mod2`
