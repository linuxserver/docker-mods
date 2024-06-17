# MediaInfo Plugin Support - Docker mod for Emby

This mod adds support for the Emby's MediaInfo plugin https://github.com/Cheesegeezer/MediaInfoWiki/wiki for Linuxserver.io's Emby container https://github.com/linuxserver/docker-emby.

Supports the Ubuntu version of the Emby container.  This mod will only work on amd64 because the Roku BIF file creation tool is compiled only for Linux x86 64-bit machines.  See https://developer.roku.com/en-gb/docs/developer-program/media-playback/trick-mode/bif-file-creation.md for more information.

In Emby Docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:emby-mediaserver`, such as:
- docker-compose:
  ```yaml
  environment:
    - DOCKER_MODS=linuxserver/mods:emby-mediaserver-plugin
  ```
- docker cli:
  ```sh
  -e DOCKER_MODS=linuxserver/mods:emby-mediaserver-plugin
  ```

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:emby-mediaserver-plugin|linuxserver/mods:universal-mod2`

# Settings in Emby
Configure the Media Toolbox plugin, applications installed will be located as follows:
- MediaInfoCL in `/usr/bin/mediainfo`
- MKVPropEdit in `/usr/bin/mkvpropedit`
- BifTool in `/usr/bin/biftool`
