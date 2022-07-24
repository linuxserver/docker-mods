# Calibre - Docker mod for 64-bit Ubuntu-based containers

This mod adds the calibre binary to calibre-web, or other *64-bit Ubuntu-based* containers, for ebook conversions.

In calibre-web docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-calibre` to enable.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-calibre|linuxserver/mods:other-mod`
