# APT Install - Universal Docker mod

Using this mod you can install any package during starup by providing it through the environment variable `APT_PACKAGES`. This is then passed into the installation command as such: `apt install -y --no-install-recommends ${APT_PACKAGES}`.

In any docker container arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-apt-install`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-apt-install|linuxserver/mods:universal-stdout-logs`

For example, to install `rsync`, `git` and `nginx` add the following lines to your docker compose service:
```yaml
- DOCKER_MODS=linuxserver/mods:universal-apt-install
- APT_PACKAGES=rsync git nginx
```
