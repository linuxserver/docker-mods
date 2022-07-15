# Calibre - Docker mod for Ubuntu-based x86_64 containers

This mod adds the calibre binary to calibre-web, or other *Ubuntu-based* containers (**x86_64 only**), for ebook conversions.

In calibre-web docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-calibre` to enable.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-calibre|linuxserver/mods:other-mod`
