# scikit-learn - Docker mod for code-server/openvscode-server

This mod adds `scikit-learn` and `jupyter` to code-server/openvscode-server, to be installed/updated during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-scikit-learn`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-scikit-learn|linuxserver/mods:code-server-prolog`
