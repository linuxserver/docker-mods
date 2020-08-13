# Ffmpeg - Docker mod for swag

This mod adds ffmpeg to swag, to be installed/updated during container start.

In swag docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-ffmpeg`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-ffmpeg|linuxserver/mods:swag-mod2`
