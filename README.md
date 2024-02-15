# Rsync - Docker mod for openssh-server

This mod adds rsync to openssh-server, to be installed/updated during container start.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:openssh-server-rsync`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:openssh-server-rsync|linuxserver/mods:openssh-server-mod2`

# Mod creation instructions

* Fork the repo, create a new branch based on the branch `template`.
* Edit the `Dockerfile` for the mod. `Dockerfile.complex` is only an example and included for reference; it should be deleted when done.
* Inspect the `root` folder contents. Edit, add and remove as necessary.
* After all init scripts and services are created, run `find ./  -path "./.git" -prune -o \( -name "run" -o -name "finish" -o -name "check" \) -not -perm -u=x,g=x,o=x -print -exec chmod +x {} +` to fix permissions.
* Edit this readme with pertinent info, delete these instructions.
* Finally edit the `.github/workflows/BuildImage.yml`. Customize the vars for `BASEIMAGE` and `MODNAME`. Set the versioning logic and `MULTI_ARCH` if needed.
* Ask the team to create a new branch named `<baseimagename>-<modname>`. Baseimage should be the name of the image the mod will be applied to. The new branch will be based on the `template` branch.
* Submit PR against the branch created by the team.


## Tips and tricks

* Some images have helpers built in, these images are currently:
    * [Openvscode-server](https://github.com/linuxserver/docker-openvscode-server/pull/10/files)
    * [Code-server](https://github.com/linuxserver/docker-code-server/pull/95)
