# Rsync - Docker mod for openssh-server

This mod adds rsync to openssh-server, to be installed/updated during container start.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:openssh-server-rsync`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:openssh-server-rsync|linuxserver/mods:openssh-server-mod2`

# Mod creation instructions

* Fork the repo, create a new branch based on the branch `template`.
* Edit the `Dockerfile` for the mod. `Dockerfile.complex` is only an example and included for reference; it should be deleted when done.
* Inspect the `root` folder contents. Edit, add and remove as necessary.
* Edit this readme with pertinent info, delete these instructions.
* Finally edit the `.github/workflows/BuildImage.yml`. Customize the build branch, and the vars for `BASEIMAGE` and `MODNAME`.
* Ask the team to create a new branch named `<baseimagename>-<modname>`. Baseimage should be the name of the image the mod will be applied to. The new branch will be based on the `template` branch.
* Submit PR against the branch created by the team.


## Tips and tricks

* To decrease startup times when multiple mods are used, we have consolidated `apt-get update` down to one file. As seen in the [nodejs mod](https://github.com/linuxserver/docker-mods/tree/code-server-nodejs/root/etc/cont-init.d)
* Some images has helpers built in, these images are currently:
    * [Openvscode-server](https://github.com/linuxserver/docker-openvscode-server/pull/10/files)
    * [Code-server](https://github.com/linuxserver/docker-code-server/pull/95)
