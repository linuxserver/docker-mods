# Opencl-Intel - Docker mod for Jellyfin

This mod adds opencl-intel to jellyfin, to be installed/updated during container start.

In jellyfin docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:jellyfin-opencl-intel`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:jellyfin-opencl-intel|linuxserver/mods:jellyfin-mod2`
