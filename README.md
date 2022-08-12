# ffmpeg - Docker mod for lazylibrarian

This mod adds ffmpeg to lazylibrarian, to be installed/updated during container start.

In lazylibrarian docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:lazylibrarian-ffmpeg`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:lazylibrarian-ffmpeg|linuxserver/mods:universal-calibre`

To enable it you can set the ffmpeg path under Settings > Processing > External Programs to `ffmpeg` in the LazyLibrarian Web UI.
