# Dashboard Docker mod for SWAG

This mod adds a dashboard to SWAG powered by [Goaccess](https://goaccess.io/).

**Currently only works with a subdomain, not a subfolder.**

# Enable

In the container's docker arguments, set an environment variable DOCKER_MODS=linuxserver/mods:swag-dashboard

If adding multiple mods, enter them in an array separated by |, such as DOCKER_MODS=linuxserver/mods:swag-dashboard|linuxserver/mods:swag-mod2

# Usage

Navigate to `dashboard.domain.com` from your LAN to view the dashboard.

You can remove the allow/deny in `/config/nginx/proxy-confs/dashboard.subdomain.com` to expose it (on a VPS for example), and instead protect it some other way (like Authelia for example).

## Notes 
- The application discovery scans the proxy configs and looks for the following structure in accordance with the samples:
  ```yaml
    set $upstream_app <container/address>;
    set $upstream_port <port>;
    set $upstream_proto <protocol>;
    proxy_pass $upstream_proto://$upstream_app:$upstream_port;
    ```
- Either [Swag Maxmind mod](https://github.com/linuxserver/docker-mods/tree/swag-maxmind) or [Swag DBIP mod](https://github.com/linuxserver/docker-mods/tree/swag-dbip) are required to enable the geo location graph.

# Example
![Example](.assets/example.png)
