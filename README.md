# PowerShell - Docker mod for code-server/openvscode-server

This mod adds PowerShell to code-server/openvscode-server, to be installed/updated during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-powershell`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-powershell|linuxserver/mods:code-server-mod2`
