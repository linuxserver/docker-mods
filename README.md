# Flutter Beta - Docker mod for code-server and openvscode-server

This mod adds a Flutter beta dev environment to code-server and openvscode-server, to be installed/updated during container start. The environment is already configured to run browser apps.

```
flutter create myapp
cd myapp
flutter run --web-port=8989 
```

Open a browser pointing to:

```
https://my-code-server-host.com/proxy/8989

or

https://8989.my-code-server-host.com
```

When editing the code, press r and refresh the web page, or install the Flutter extension for code-server or openvscode-server.

In code-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:code-server-flutter`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:code-server-flutter|linuxserver/mods:code-server-mod2`
