# Flood For Transmission - Transmission UI Mod

This mod adds Flood For Transmission to Transmission, to be installed/updated during container start.

In Transmission docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:transmission-floodui`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:transmission-floodui|linuxserver/mods:openssh-server-mod2`

## Notes

* This mod will *overwrite* any existing `TRANSMISSION_WEB_HOME` environment variable that has been set.
