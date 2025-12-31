# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.23 AS buildstage

ARG MOD_VERSION

RUN \
  echo "**** grab flood-for-transmission ****" && \
  if [ -z "${MOD_VERSION}" ]; then \
    MOD_VERSION=$(curl -s "https://api.github.com/repos/johman10/flood-for-transmission/releases/latest" \
    | jq -rc ".tag_name"); \
  fi && \
  curl -fo \
    /tmp/flood.tar.gz -L \
    "https://github.com/johman10/flood-for-transmission/releases/download/${MOD_VERSION}/flood-for-transmission.tar.gz" && \
  mkdir -p /root-layer/themes/flood-for-transmission && \
  tar xzf \
    /tmp/flood.tar.gz -C \
    /root-layer/themes/flood-for-transmission --strip-components=1 && \
  ln -s /config/themes/flood-for-transmission/config.json /root-layer/themes/flood-for-transmission/config.json

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="thespad"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
