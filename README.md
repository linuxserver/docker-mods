# .NET Core SDK - Docker mod for code-server/openvscode-server

This mod adds .NET CORE SDK to code-server and openvscode-server. 

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-dotnet`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-dotnet|linuxserver/mods:code-server-mod2`

The [current release and all current lts releases](https://dotnet.microsoft.com/download/dotnet-core) will be made available inside the container (5.0.101, 3.1.404 and 2.1.811 as of 2020/12/13).

The binaries are accessible at `/dotnet_<sdkversion>/dotnet` for each respective version.

The current version binary is symlinked from `/usr/local/bin/dotnet` so it can be called via `dotnet` from anywhere.
