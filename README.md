# par2cmdline-turbo - SABnzbd mod

This mod adds the [par2cmdline-turbo](https://github.com/animetosho/par2cmdline-turbo) fork as a replacement for the standard par2cmdline package.

In the SABnzbd docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:sabnzbd-par2cmdline-turbo`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:sabnzbd-par2cmdline-turbo|linuxserver/mods:openssh-server-mod2`
