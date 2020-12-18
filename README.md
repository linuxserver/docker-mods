# 4K Hardware Transcode Mod - Docker mod for plex

This mod adds  [Beignet Comet Lake GCC Mode](https://github.com/rcombs/beignet/tree/comet-lake)

Beignet is an open source implementation of the OpenCL specification - a generic compute oriented API. This code base contains the code to run OpenCL programs on Intel GPUs which basically defines and implements the OpenCL host functions required to initialize the device, create the command queues, the kernels and the programs and run them on the GPU. The code base also contains the compiler part of the stack which is included in backend/. For more specific information about the compiler, please refer to backend/README.md

In plex docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:plex-transcode-mod`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:plex-transcode-mod|linuxserver/mods:plex-mod2`
