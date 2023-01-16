# cloudflare_real-ip - Docker mod for SWAG

This mod adds a startup script that gets the IPs from Cloudflare's edge servers, and outputs them in a format Nginx can use with `set_real_ip_from`.

It reads this [list for IPv4](https://www.cloudflare.com/ips-v4), and this [list for IPV6](https://www.cloudflare.com/ips-v6).

In SWAG docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-cloudflare-real-ip`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-cloudflare-real-ip|linuxserver/mods:swag-f2bdiscord`

## Mod usage instructions

The file gets placed in your persistent data, at `/config/nginx/cf_real-ip.conf`

To enable nginx to read the IPs from this file, you need the following in your `nginx.conf` (`http` section):

```nginx
real_ip_header X-Forwarded-For;
real_ip_recursive on;
include /config/nginx/cf_real-ip.conf;
```

~~I also recommend including your docker-network as a valid ip `set_real_ip_from 172.17.0.0/16;` in the snippet above.~~

This mod now adds `127.0.0.1` and *tries* to add the real ip from the interfaces in the container.

## Versions

* **16.01.23:** - Add 127.0.0.1 and format shell scripts.
* **21.01.21:** - Fix bug when mod runs before internet-access.
