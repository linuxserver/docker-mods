# SlurpIT - Docker mod for installing the SlurpIT plugin for netbox

This mod adds the slurpit plugin to a netbox container.

In netbox docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:netbox-slurpit`

Update your `configuration.py` to include the plugin

```
...
# Enable installed plugins. Add the name of each plugin to the list.
PLUGINS = ['slurpit_netbox']

...
```