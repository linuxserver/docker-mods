# drop2beets - Docker mod for beets

This mod adds drop2beets to beets, to be installed/updated during container start.

In beets docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:beets-drop2beets`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:beets-drop2beets|linuxserver/mods:beets-mod2`
