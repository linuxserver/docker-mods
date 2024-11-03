# Opencl-Intel - Docker mod for Jellyfin

This mod adds opencl-intel to jellyfin, to be installed/updated during container start.

In jellyfin docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:jellyfin-opencl-intel`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:jellyfin-opencl-intel|linuxserver/mods:jellyfin-mod2`

If your system is equipped with an older CPU, you will need to pin the Opencl-Intel mod to specific version.  Intel has deprecated support for "legacy" CPUs with pre-Tigerlake GPUs.  This includes desktop CPUs prior to Rocketlake, laptop CPUs prior to Tigerlake, and low power CPUs prior to Alderlake-N.  If you are unsure which CPU family you have, if your iGPU model number is in the 500 and 600 range, you have a "legacy" Intel CPU.

For legacy CPUs, you must pin the Opencl-Intel mod to version 24.35.30872.22.  Versions newer than this will cause tone mapping in Jellyfin to fail due to the openCL runtime not supporting your legacy CPU.  Appending the environment variable with the version number will install that specific version.  `DOCKER_MODS=linuxserver/mods:jellyfin-opencl-intel-24.35.30872.22`
