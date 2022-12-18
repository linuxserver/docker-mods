# HACS - Docker mod for Home Assistant

This mod adds Home Assistant Community Store (HACS) to Home Assistant, to be installed during container start.

In Home Assistant docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:homeassistant-hacs`
To enable in Home Assistant, add integration `HACS` in the gui and go through the wizard (need to set up Github Oauth).

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:homeassistant-hacs|linuxserver/mods:custom-mod2`

## Notes:
- The developer of HACS only supports official Home Assistant installs (Linuxserver image is not official), therefore they will not support this method of installation. Please see here for support info: https://www.linuxserver.io/support
- HACS does not contain add-ons, as add-ons are docker container based and are only supported in Home Assistant OS/Supervised.
- 
