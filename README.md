# Extension Arguments - Docker mod for code-server/openvscode-server

This mod installs code-server/openvscode-server extensions at startup. The list of extensions to be installed should be provided using environment variable `VSCODE_EXTENSION_IDS` separated by `|`.

__NOTE__:
Since transitioning from `v3.12.0` to `v4.0.x` `code-server` has been forced to use a new Extensions Gallery / Marketplace. This results in a smaller set of plugins being available to install. Please take this into account before opening an Issue! 

A workaround for this is to use the environment variable `EXTENSIONS_GALLERY` to provide a different marketplace URL. The commandline installer used by this plugin will also use the marketplace provided by this variable.

Please refer to the [code-server FAQ](https://github.com/coder/code-server/blob/main/docs/FAQ.md#how-do-i-use-my-own-extensions-marketplace) for additional information.


For example, to install the `vscode-docker` and `vscode-icons` extensions add the following lines to your docker compose service:
```yaml
  environment:
    DOCKER_MODS: 'linuxserver/mods:code-server-docker|linuxserver/mods:code-server-extension-arguments'
    VSCODE_EXTENSION_IDS: 'vscode-icons-team.vscode-icons|ms-azuretools.vscode-docker'
    ## Optionally use a different marketplace if required extensions are unavailable. e.g.:
    # EXTENSIONS_GALLERY: '{"serviceUrl": "https://extensions.coder.com/api"}'
    # EXTENSIONS_GALLERY: '{"serviceUrl": "https://open-vsx.org/vscode/gallery", "itemUrl": "https://open-vsx.org/vscode/item"}'
```
