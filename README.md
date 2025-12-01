# Bat - Docker mod for code-server

This mod adds [bat](https://github.com/sharkdp/bat) to code-server, to be installed/updated during container start.

Bat is a cat(1) clone with syntax highlighting and Git integration.

In code-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-bat`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-bat|linuxserver/mods:openssh-server-mod2`

### Bat-extras and Ripgrep

This mod also includes [bat-extras](https://github.com/eth-p/bat-extras) which has a dependency of [ripgrep](https://github.com/BurntSushi/ripgrep). Ripgrep has also been included because it is a requirment of bat-extras.

### Aliases

This mod includes aliases for `bat` in `bash` and `zsh`. Under Ubuntu `bat` gets installed as `batcat` to avoid a name collision. So, for convenience, an alias to set `bat="batcat"` is included for both `bash` and `zsh`. 