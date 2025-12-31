# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.23 AS buildstage

ARG MOD_VERSION

RUN \
  echo "**** grab transmission-web-control ****" && \
  mkdir -p /root-layer/themes && \
  if [ -z "${MOD_VERSION}" ]; then \
    MOD_VERSION=$(curl -s "https://api.github.com/repos/transmission-web-control/transmission-web-control/releases/latest" \
    | jq -rc ".tag_name"); \
  fi && \
  curl -o \
    /tmp/transmission-web-control.tar.gz -L \
    "https://github.com/transmission-web-control/transmission-web-control/releases/download/${MOD_VERSION}/dist.tar.gz" && \
  mkdir -p /root-layer/themes/transmission-web-control && \
  tar xzf \
    /tmp/transmission-web-control.tar.gz -C \
    /root-layer/themes/transmission-web-control --strip-components=2

# copy local files
COPY root/ /root-layer/

# ## Single layer deployed image ##
FROM scratch

LABEL maintainer="FujiZ"

# # Add files from buildstage
COPY --from=buildstage /root-layer/ /
