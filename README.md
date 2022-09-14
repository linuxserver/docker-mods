# Calibre-web - DriveThruRPG Metadata Provider

This adds a new metadata provider for `calibre-web` which will look for information on DriveThruRPG.com

After installing, DriveThruRPG will be an option when pulling in metadata about a book.

In `calibre-web` docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:calibre-web-dtrpg-metadata` to enable.

If adding multiple mods, enter them in an array separated by `|`, 
such as `DOCKER_MODS=linuxserver/mods:universal-calibre|linuxserver/mods:calibre-web-dtrpg-metadata`
