# jellyfin-amd - Docker mod for Jellyfin

This mod adds the mesa libraries (v20.1+) needed for hardware encoding (VAAPI) on AMD GPUs to the Jellyfin Docker container (`latest` tag).

To enable, you need to add the 2 following entries:
- Device mapping for `/dev/dri`
  - docker-compose: 
    ```yaml
        devices:
          - /dev/dri:/dev/dri
    ```
  - docker cli
    ```sh
    --device /dev/dri:/dev/dri
    ```
- Environment Variable: `DOCKER_MODS=linuxserver/mods:jellyfin-amd`
  - docker-compose:
    ```yaml
        environment:
          - DOCKER_MODS=linuxserver/mods:jellyfin-amd
    ```
  - docker cli:
    ```sh
    -e DOCKER_MODS=linuxserver/mods:jellyfin-amd
    ```

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:jellyfin-amd|linuxserver/mods:jellyfin-mod2`

## Settings in Jellyfin
Under server administration in `Server > Playback` the `Hardware acceleration` can be set to `Video Acceleration API (VAAPI)` and the `VA API Device` has to be set to the device given in the Docker configuration. For example `/dev/dri/renderD128`.
