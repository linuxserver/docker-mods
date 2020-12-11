# Proxy-conf - Docker mod for Nginx

This mod adds some of the [proxy-conf](https://github.com/linuxserver/reverse-proxy-confs) functionality that is baked into [SWAG](https://github.com/linuxserver/docker-swag), to Nginx.

This mod does some reshuffling to the files that originally ships with our Nginx image.

| File | Change |
| --- | --- |
| site-confs/default | Added include directives to load the files from proxy-confs/ |
| nginx.conf | Moved some directives to proxy.conf. Added the required map for websockets |
| proxy.conf | Direct copy from SWAG |
| ssl.conf | Based on the same file from SWAG, but changed certificate location |

In nginx docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:nginx-proxy-confs`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:nginx-proxy-confs|linuxserver/mods:universal-git`
