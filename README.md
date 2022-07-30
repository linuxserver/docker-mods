# Golang - Docker mod for code-server and openvscode-server

This mod adds golang/go to code-server and openvscode-server.

In code-server or openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-golang`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-golang|linuxserver/mods:code-server-mod2`

## Available Image Tags
- `code-server-golang` : installs the latest stable version
- `code-server-golang-X` : installs the latest major `X` version
- `code-server-golang-X.X` : installs the latest minor `X.X` version
- `code-server-golang-X.X.X` : installs the specific `X.X.X` version

### Examples
- `linuxserver/mods:code-server-golang-1.13` will install the latest `1.13` release, which is `1.13.10` as of 2020/05/07
- `linuxserver/mods:code-server-golang-1` will install the latest `1` release, which is `1.14.2` as of 2020/05/07
- `linuxserver/mods:code-server-golang` will install the latest stable release, which is `1.14.2` as of 2020/05/07
- `linuxserver/mods:code-server-golang-1.14.2` will install the specific `1.14.2` release

Visit https://hub.docker.com/r/linuxserver/mods/tags?page=1&name=code-server-golang to see all available tags
