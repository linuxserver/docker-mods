## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage

ARG FLOOD_VERSION

RUN \
  echo "**** grab flood-for-transmission ****" && \
  if [ -z ${FLOOD_VERSION+x} ]; then \
    FLOOD_VERSION=$(curl -s "https://api.github.com/repos/johman10/flood-for-transmission/releases/latest" \
    | jq -rc ".tag_name"); \
  fi && \
  curl -o \
    /tmp/flood.tar.gz -L \
    "https://github.com/johman10/flood-for-transmission/releases/download/${FLOOD_VERSION}/flood-for-transmission.tar.gz" && \
  mkdir -p /root-layer/themes/flood-for-transmission && \
  tar xzf \
    /tmp/flood.tar.gz -C \
    /root-layer/themes/flood-for-transmission --strip-components=1

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="thespad"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
