# run_custom_before_legacy - Universal docker mod

This mod adds a step in the init process for you to hijack, convenient when you want to execute custom code earlier on in the process than custom-cont.d allows you to do.

The file this mod executes lives on the root, as `/init-run-custom-before-legacy`, map this as a file using volume mounts to replace it's content

## Usage

Here an example snippet to help you get started using this docker mod.

### docker-compose ([recommended](https://docs.linuxserver.io/general/docker-compose))

```yaml
  swag:
    image: lscr.io/linuxserver/nginx
    container_name: nginx
    environment:
      PUID: 1000
      PGID: 1000
      TZ: Europe/London
      DOCKER_MODS: linuxserver/mods:universal-run_custom_before_legacy
    volumes:
      - /path/to/appdata/config:/config
      - /path/to/custom/script:/init-run-custom-before-legacy
    restart: unless-stopped
```

## Parameters

Container images/mods are configured using parameters passed at runtime (such as those above).

| Parameter | Function | Notes |
| :----: | --- | --- |
| `DOCKER_MODS` | Enable this docker mod with `linuxserver/mods:universal-run_custom_before_legacy` | If adding multiple mods, enter them in an array separated by `\|`, such as `DOCKER_MODS: linuxserver/mods:universal-run_custom_before_legacy\|linuxserver/mods:universal-mod2` |
