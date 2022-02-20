# Package Install - Universal Docker mod

Using this mod you can install any package during starup by providing it through the environment variable `INSTALL_PACKAGES`. This is then passed into the installation command as such: `apt install -y --no-install-recommends ...` or `apk add --no-cache ...` for Alpine based images.

In any docker container arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-package-install`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-package-install|linuxserver/mods:universal-stdout-logs`. Similarly, for installing multiple packages separate them by `|`.
E.g., to install `rsync`, `git` and `nginx` add the following lines to your docker compose service:
```yaml
- DOCKER_MODS=linuxserver/mods:universal-package-install
- INSTALL_PACKAGES=rsync|git|nginx
```