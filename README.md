# Dashboard Docker mod for SWAG

This mod adds a dashboard to SWAG powered by [Goaccess](https://goaccess.io/).

**Currently only works with a subdomain, not a subfolder.**

# Enable

In the container's docker arguments, set an environment variable DOCKER_MODS=linuxserver/mods:swag-dashboard

If adding multiple mods, enter them in an array separated by |, such as DOCKER_MODS=linuxserver/mods:swag-dashboard|linuxserver/mods:swag-mod2

# Usage

Navigate to `dashboard.domain.com` from your LAN to view the dashboard.

## Notes 
- The application discovery scans all the conf files and looks for the following structure in accordance with the samples, incorrect discovery results can be fixed by using the structure.
  ```yaml
    set $upstream_app something;
    set $upstream_port 123;
    set $upstream_proto http;
    proxy_pass $upstream_proto://$upstream_app:$upstream_port;
    ```
- [Swag Maxmind mod](https://github.com/linuxserver/docker-mods/tree/swag-maxmind) is required to enable the geo location graph

# Example
![Example](.assets/example.png)
