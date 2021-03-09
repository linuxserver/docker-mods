# Auto-reload - Docker mod for Nginx based images

This mod allows Nginx to be reloaded automatically whenever there are valid changes to the following files and folders:
- /config/nginx/authelia-location.conf
- /config/nginx/authelia-server.conf
- /config/nginx/geoip2.conf
- /config/nginx/ldap.conf
- /config/nginx/nginx.conf
- /config/nginx/proxy-confs
- /config/nginx/proxy.conf
- /config/nginx/site-confs
- /config/nginx/ssl.conf

In the container's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-auto-reload`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-auto-reload|linuxserver/mods:swag-mod2`

If you'd like for Nginx to be reloaded when other files or folders are modified (not included in our default list above), set a new environment variable, `WATCHLIST`, and set it to a list of container relative paths separated by `|` like the below example:

`WATCHLIST="/config/nginx/custom.conf|/config/nginx/customfolder"`
