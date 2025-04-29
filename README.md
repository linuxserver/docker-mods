# Dashboard Docker mod for SWAG

This mod adds a dashboard to SWAG powered by [Goaccess](https://goaccess.io/).

**Currently only works with a subdomain, not a subfolder.**

# Enable

In the container's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:swag-dashboard`.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:swag-dashboard|linuxserver/mods:swag-mod2`.

## Internal access using `<server-ip>:81`

Add a mapping of `81:81` to swag's docker run command or compose.

## Internal access using `dashboard.domain.com`

Requires an internal DNS, add a rewrite of `dashboard.domain.com` to your server's IP address.

## External access using `dashboard.domain.com`

Remove the allow/deny lines in `/config/nginx/proxy-confs/dashboard.subdomain.com`, and instead secure it some other way (like Authelia for example).

## Usage 

- The application discovery scans for a list of known services, as well as enabled custom proxy confs that contain the following format:
  ```yaml
    set $upstream_app <container/address>;
    set $upstream_port <port>;
    set $upstream_proto <protocol>;
    proxy_pass $upstream_proto://$upstream_app:$upstream_port;
    ```
- Either [Swag Maxmind mod](https://github.com/linuxserver/docker-mods/tree/swag-maxmind) or [Swag DBIP mod](https://github.com/linuxserver/docker-mods/tree/swag-dbip) are required to enable the geo location graph.
- Either Maxmind's or DB-IP's ASN mmdb are required under `/config/geoip2db/asn.mmdb` to enable the ASN graph.
- To clear the dashboard stats, you must remove the logs (/config/log/nginx) and **recreate** the container.

## Dashboard Support 

There's a stats endpoint for integration with dashboards under `https://dashboard.domain.com/?stats=true`.

## External Support
- External fail2ban (not required when using swag's fail2ban) can be supported by mounting it to swag `- /path/to/host/fail2ban.sqlite3:/dashboard/fail2ban.sqlite3:ro`.
- External logs (not required when using swag's logs) can be supported by mounting it to swag `- /path/to/host/logs:/dashboard/logs:ro`.

# Example
![Example](.assets/example.png)
