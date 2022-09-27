# Package Install - Universal Docker mod

Using this mod you can install any OS or Python packages during startup by providing them through the environment variables `INSTALL_PACKAGES` and `INSTALL_PIP_PACKAGES`. These are then passed into the installation commands as such: `apt-get install -y --no-install-recommends ...` in Ubuntu and `apk add --no-cache ...` in Alpine based images for OS packages and `pip install ...` for python packages.

To enable, in docker container arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-package-install` and env vars `INSTALL_PACKAGES` and/or `INSTALL_PIP_PACKAGES`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-package-install|linuxserver/mods:universal-stdout-logs`.

Similarly, for installing multiple packages separate them by `|`.
E.g., to install `rsync`, `git` and `nginx` OS packages and `apprise` python package, add the following lines to your docker compose service:
```yaml
- DOCKER_MODS=linuxserver/mods:universal-package-install
- INSTALL_PACKAGES=rsync|git|nginx
- INSTALL_PIP_PACKAGES=apprise
```

## Notes:
- Package names entered should match the names in the relevant distro repo: https://pkgs.alpinelinux.org/packages or https://packages.ubuntu.com/
- Setting the env var `INSTALL_PIP_PACKAGES` will result in automatic install of the `python3-dev` and `python3-pip` OS packages, updating of `pip` to the latest version and installation of the latest `setuptools` and `wheel` packages to set up the necessary environment.
- Any other OS dependency such as `make` or `git`, which may be needed by the pip install process, should be manually added to `INSTALL_PACKAGES`.
- The OS packages defined will be installed first, followed by the pip packages.
- Pip will also use the relevant linuxserver wheel repo as an additional index to pull prebuilt wheels for common packages (ie. https://wheel-index.linuxserver.io/ubuntu/ and https://wheel-index.linuxserver.io/alpine-3.16/).
