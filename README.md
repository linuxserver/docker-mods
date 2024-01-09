# Remove Codecs - Docker mod for plex

This mod removes all codec subfolders from Plex's `/config/Library/Application Support/Plex Media Server/Codecs/` folder, preserves the `.device-id`, and allows Plex to repopulate the codecs folder while starting up. This mod should not be necessary in most cases, but if you have issues with codecs preventing playback this mod may be useful as a one-time solution and can be removed after running once.

In plex docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:plex-remove-codecs`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:plex-remove-codecs|linuxserver/mods:plex-mod2`
