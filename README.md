# Universal Wait for Internet - Docker mod for an waiting on an active internet connection

This mod is used to help wait until an active internet connection is established. By default, it will attempt to access https://www.linuxserver.io/. If after 60s a connection cannot be established, it will wait for 10s before attempting again. This will happen until an active connection is established.

In any docker container arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-wait-for-internet`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-wait-for-internet|linuxserver/mods:universal-git`