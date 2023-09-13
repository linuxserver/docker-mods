# par2cmdline-turbo - SABnzbd mod

## par2cmdline-turbo is now included in the SABnzbd docker image and this mod has been deprecated

This mod adds the [par2cmdline-turbo](https://github.com/animetosho/par2cmdline-turbo) fork as a replacement for the standard par2cmdline package.

It is supported on both amd64 and aarch64 (arm64) platforms, but not armhf (arm32).

In the SABnzbd docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:sabnzbd-par2cmdline-turbo`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:sabnzbd-par2cmdline-turbo|linuxserver/mods:openssh-server-mod2`
