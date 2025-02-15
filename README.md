# Maxmind Docker mod for Nginx based images

This mod adds the maxmind database to nginx using the license key defined in the environment variable.

This mod downloads the `GeoLite2-City.mmdb` database under `/config/geoip2db`, the database is updated weekly.

**This mod should not be enabled together with the swag-dbip mod.**

Follow these steps to enable the maxmind mod:

1. Acquire a maxmind license here: https://www.maxmind.com/en/geolite2/signup
2. In the container's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-maxmind`
   
   If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-maxmind|linuxserver/mods:swag-mod2`
3. In the container's docker arguments, set the following environment variables:
    - `MAXMINDDB_LICENSE_KEY=<license-key>` with your license key.
    - `MAXMINDDB_USER_ID=<account-id>` with your **account id**.
4. Recreate the container to apply the changes.
5. Add the following line to `/config/nginx/nginx.conf` under the `http` section:
   
   ```nginx
   include /config/nginx/maxmind.conf;
   ```
5. Edit `/config/nginx/maxmind.conf` and add countries to the blocklist / whitelist according to the comments, for example:
   
    ```nginx
    map $geoip2_data_country_iso_code $geo-whitelist {
        default no;
        GB yes;
    }

    map $geoip2_data_country_iso_code $geo-blacklist {
        default yes;
        US no;
    }
    ```
6. Use the definitions in the following way:
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
7. Restart the container to apply the changes.
