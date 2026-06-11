# NetBox DNS - Docker mod for installing the netbox-plugin-dns plugin for NetBox

This mod adds the [NetBox DNS](https://github.com/sys4/netbox-plugin-dns) plugin (PyPI: `netbox-plugin-dns`) to a netbox container.

In netbox docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:netbox-dns`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:netbox-dns|linuxserver/mods:netbox-mod2`

Update your `configuration.py` to include the plugin

```
...
# Enable installed plugins. Add the name of each plugin to the list.
PLUGINS = ['netbox_dns']

...
```

On the next container start, the mod adds `netbox-plugin-dns` to the pip install list before NetBox runs its database migrations, and the plugin's tables will be created automatically.

## Removal

Before removing `DOCKER_MODS`, remove `'netbox_dns'` from the `PLUGINS` list in your `configuration.py`. Otherwise NetBox will fail to start because the plugin package will no longer be installed but is still referenced in the configuration.
