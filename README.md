# Nodejs - Docker mod for code-server/openvscode-server

This mod adds a nodejs v19 dev environment to code-server/openvscode-server, to be installed/updated during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=cheekysim/mods:code-server-nodejs`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=cheekysim/mods:code-server-nodejs|cheekysim/mods:code-server-mod2`