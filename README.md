# Fonts - Docker mod for firefox

This mod adds font packages to firefox, to be installed/updated during container start.

In firefox docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:firefox-fonts`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:firefox-fonts|linuxserver/mods:firefox-mod2`
