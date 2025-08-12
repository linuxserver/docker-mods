# NZBGet Essentials

This mod adds a few esssential binaries to NZBGet container.

ffmpeg
openssl
p7zip
unzip
unrar
python3
par2

In NZBGet docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:nzbget-essentials`

If adding multiple mods, enter them in an array separated by |, such as `DOCKER_MODS=linuxserver/mods:nzbget-essentials|linuxserver/mods:nzbget-mod2`
