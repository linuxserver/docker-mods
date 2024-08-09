# kcc - Docker mod for Calibre Web

This mod adds kcc and its multitude of ebook processing (upscale, stretch, right to left for manga...) to Calibre Web, to be installed/updated during container start.

In any container docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:calibre-web-kcc`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:calibre-web-kcc|linuxserver/mods:calibre-web-mod2`