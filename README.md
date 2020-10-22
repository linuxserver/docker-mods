# Zsh / Oh My Zsh - Docker mod for code-server

This mod adds `zsh` and `Oh My Zsh` to code-server, to be installed/updated during container start.

In code-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-zsh`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-zsh|linuxserver/mods:code-server-prolog`

`Oh My Zsh` is installed at `/config/.oh-my-zsh` and can be updated via `omz update` in terminal.
