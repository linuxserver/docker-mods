# syntax=docker/dockerfile:1

## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.19 as buildstage

ARG MOD_VERSION

# copy local files
COPY root/ /root-layer/

# Add version to script
RUN \
  MOD_VERSION="${MOD_VERSION:-unknown}" && \
  sed -i -e "s/{{VERSION}}/$MOD_VERSION/" \
    /root-layer/usr/local/bin/striptracks.sh \
    /root-layer/etc/s6-overlay/s6-rc.d/init-mod-radarr-striptracks-add-package/run

## Single layer deployed image ##
FROM scratch

LABEL org.opencontainers.image.source=https://github.com/TheCaptain989/radarr-striptracks
LABEL org.opencontainers.image.description="A Docker Mod to Radarr/Sonarr to automatically strip out unwanted audio and subtitle streams"
LABEL org.opencontainers.image.licenses=GPL-3.0-only
LABEL org.opencontainers.image.authors="TheCaptain989"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
