# NPM Global - Docker mod for code-server/openvscode-server

This mod sets the NPM global folder to `/config` in code-server/openvscode-server during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-npmglobal`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-nodejs|linuxserver/mods:code-server-npmglobal`

**This mod requires npm installed via a different mod**
