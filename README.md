# DBIP Docker mod for Nginx based images

This mod downloads the `dbip-country-lite.mmdb` database under `/config/geoip2db`, the database is updated weekly.

**This mod should not be enabled together with the swag-maxmind mod.**

Follow these steps to enable the dbip mod:

1. In the container's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-dbip`
   
   If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-dbip|linuxserver/mods:swag-mod2`
2. Add the following line to `/config/nginx/nginx.conf` under the `http` section:
   
   ```nginx
   include /config/nginx/dbip.conf;
   ```
3. Edit `/config/nginx/dbip.conf` and add countries to the blocklist / whitelist according to the comments, for example:
   
    ```nginx
    map $geoip2_data_country_iso_code $geo-whitelist {
        default no;
        UK yes;
    }

    map $geoip2_data_country_iso_code $geo-blacklist {
        default yes;
        US no;
    }
    ```
4. Use the definitions in the following way:
   ```nginx
    server {
        listen 443 ssl;
        listen [::]:443 ssl;

        server_name some-app.*;
        include /config/nginx/ssl.conf;
        client_max_body_size 0;

        if ($lan-ip = yes) { set $geo-whitelist yes; }
        if ($geo-whitelist = no) { return 404; }

        location / {
    ```
5. Recreate the container to apply the changes.
