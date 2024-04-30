# TrguiNG - Remote GUI for Transmission torrent daemon 

This mod adds TrguiNG to Transmission, to be installed/updated during container start.

In Transmission docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:transmission-trguing`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:transmission-trguing|linuxserver/mods:transmission-mod2`

## Notes

* This mod will *overwrite* any existing `TRANSMISSION_WEB_HOME` environment variable that has been set.
