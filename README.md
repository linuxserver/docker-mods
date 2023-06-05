# ENV Var Settings - Docker mod for transmission

This mod sets Transmission settings provided via environment variables.

The environment variable names are a combination of `'TRANSMISSION_'` and the
setting name capitalized with hyphens (`'-'`) converted to underscores (`'_'`). For example, the setting
`'peer-port'` can be set with environment variable `TRANSMISSION_PEER_PORT`.

In transmission docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:transmission-env-var-settings`.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:transmission-env-var-settings|linuxserver/mods:universal-wait-for-internet`
