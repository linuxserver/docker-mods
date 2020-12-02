# Absolute Series Scanner and Hama - Docker mod for plex

This mod adds [Absolute Series Scanner](https://github.com/ZeroQI/Absolute-Series-Scanner) and [Hama](https://github.com/ZeroQI/Hama.bundle) to Plex, to be downloaded/updated during container start.

In plex docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:plex-absolute-hama`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:plex-absolute-hama|linuxserver/mods:plex-mod2`
