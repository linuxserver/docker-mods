# Auto-reload - Docker mod for Nginx based images

This mod allows Nginx to be reloaded automatically whenever there are new files, or valid changes to the files in `/config/nginx`.

In the container's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-auto-reload`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-auto-reload|linuxserver/mods:swag-mod2`

If you'd like for Nginx to be reloaded when other files or folders are modified (not included in our default list above), set a new environment variable, `WATCHLIST`, and set it to a list of container relative paths separated by `|` like the below example:

`WATCHLIST="/config/nginx/custom.conf|/config/nginx/customfolder"`
