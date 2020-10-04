# apprise - Docker mod for any container

This mod adds apprise to any container, to be installed/updated during container start.

In any container docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-apprise`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-apprise|linuxserver/mods:universal-mod2`
