# SSL - Docker mod for code-server/openvscode-server

This mod adds SSL capabilities to code-server/openvscode-server

In code-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-ssl`

You will also need to set the variables `SSL_CERT_PATH` and `SSL_KEY_PATH`.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-ssl|linuxserver/mods:code-server-mod2`
