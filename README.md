# .NET Core SDK - Docker mod for code server

This mod adds .NET CORE SDK to code server. 

In code server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-dotnet`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-dotnet|linuxserver/mods:code-server-mod2`

All current [lts releases](https://dotnet.microsoft.com/download/dotnet-core) will be made available inside the container (3.1.403 and 2.1.811 as of 2020/10/14).

The binaries are accessible at `/dotnet_<sdkversion>/dotnet` for each respective version.

The latest version binary is symlinked from `/usr/local/bin/dotnet` so it can be called via `dotnet` from anywhere.
