# Heyu - Docker mod for homeassistant

This mod adds heyu to homeassistant, to be installed/updated during container start.

In homeassistant docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:homeassistant-heyu`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:homeassistant-heyu|linuxserver/mods:homeassistant-hacs`

# Mod config instructions

Heyu cannot be configured through the homeassistant interface. To configure heyu edit the config file at `/config/heyu/x10.conf`
