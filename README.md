# Extension Arguments - Docker mod for code-server

This mod installs code-server extensions at startup. The list of extensions to be installed should be provided using environment variable `VSCODE_EXTENSION_IDS` separated by `|`.

For example, to install the `vscode-docker` and `vscode-icons` extensions add the following lines to your docker compose service:
```yaml
- DOCKER_MODS=linuxserver/mods:code-server-docker|linuxserver/mods:code-server-extension-arguments
- VSCODE_EXTENSION_IDS=vscode-icons-team.vscode-icons|ms-azuretools.vscode-docker
```
