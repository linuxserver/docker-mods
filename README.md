# Rbenv - Docker mod for code-server

This mod adds [rbenv](https://github.com/rbenv/rbenv) to code-server, to be installed/updated during container start.

rbenv is a version manager tool for the Ruby programming language on Unix-like systems. It is useful for switching between multiple Ruby versions on the same machine and for ensuring that each project you are working on always runs on the correct Ruby version.

In code-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-rbenv`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-rbenv|linuxserver/mods:openssh-server-mod2`

### Shell completions

This mod includes adding [shell completions](https://github.com/rbenv/rbenv?tab=readme-ov-file#shell-completions) for `rbenv` in `bash` and `zsh`.

The zsh completion script ships with the project, but needs to be added to FPATH in zsh before it can be discovered by the shell. So, the mod will automatically detect and update the `~/.zshrc` file:

```
FPATH=~/.rbenv/completions:"$FPATH"
autoload -U compinit
compinit
```

### Ruby-build

This mod includes [ruby-build](https://github.com/rbenv/ruby-build), which allows you to run the `rbenv install` command.

It will automatically check for an existing `ruby-build` installation upon `docker build`. If it detects `ruby-build`, it will upgrade it.

You can also manually upgrade `ruby-build`, as described in the [documentation](https://github.com/rbenv/ruby-build?tab=readme-ov-file#clone-as-rbenv-plugin-using-git), without bringing down the docker instance by running:

```
git -C "$(rbenv root)"/plugins/ruby-build pull
```

### Build environment

In order to compile Ruby, you need the proper toolchain and build environment. The required system packages can be found in the [documentation](https://github.com/rbenv/ruby-build/wiki#ubuntudebianmint).

This mod will install these requirements for you:

* autoconf
* build-essential
* libffi-dev
* libgmp-dev
* libssl-dev
* libyaml-dev
* rustc
* zlib1g-dev

With these installed, you should be able to compile any of the latest stable Ruby versions, which you can find by running the command `rbenv install --list`.

### Installed Ruby versions

By default, `rbenv` is installed in `~/.rbenv`. This mod will update the permissions of that folder to ensure that your user can install new versions of Ruby into it.