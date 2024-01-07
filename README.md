# Rust - Docker mod for code-server and openvscode-server
This mod adds Rust to code-server and openvscode-server.

In code-server or openvscode-server docker arguments, set an environment variable DOCKER_MODS=linuxserver/mods:code-server-rust

If adding multiple mods, enter them in an array separated by |, such as DOCKER_MODS=linuxserver/mods:code-server-rust|linuxserver/mods:code-server-mod2

By default, the mod will install the latest stable version of Rust.  If you'd like to install a different version, you can specify the version as a tag, from a list of published tags: https://hub.docker.com/r/linuxserver/mods/tags?page=1&name=code-server-rust

Supported  architectures: 
- [x] linux/amd64
- [x] linux/aarch64

Supported docker base images:
- [x] ubuntu:jammy
