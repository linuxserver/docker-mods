# ROS2 - Docker mod for code-server and openvscode-server

This mod adds ROS2 to code-server and openvscode-server, to be installed/updated during container start.

In code-server/openvscode-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-ros2`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-ros2|linuxserver/mods:code-server-flutter`

The current release [ROS2 Humble](https://docs.ros.org/en/humble/) and its development tools will be made available inside the container.