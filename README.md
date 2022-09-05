# SVN - Docker mod for code-server/openvscode-server

This mod installs subversion and the SVN extension into code-server/openvscode-server at startup.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-svn`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-python3|linuxserver/mods:code-server-svn`
