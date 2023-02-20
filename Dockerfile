# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage

ARG TRANSMISSIONIC_VERSION

RUN \
  echo "**** grab transmissionic ****" && \
  mkdir -p /root-layer/themes && \
  if [ -z ${TRANSMISSIONIC_VERSION+x} ]; then \
    TRANSMISSIONIC_VERSION=$(curl -s "https://api.github.com/repos/6c65726f79/Transmissionic/releases/latest" \
    | jq -rc ".tag_name"); \
  fi && \
  curl -o \
    /tmp/transmissionic.zip -L \
    "https://github.com/6c65726f79/Transmissionic/releases/download/${TRANSMISSIONIC_VERSION}/Transmissionic-webui-${TRANSMISSIONIC_VERSION}.zip" && \
  unzip \
    /tmp/transmissionic.zip -d \
    /root-layer/themes && \
  mv /root-layer/themes/web /root-layer/themes/transmissionic

# copy local files
COPY root/ /root-layer/

# ## Single layer deployed image ##
FROM scratch

LABEL maintainer="thespad"

# # Add files from buildstage
COPY --from=buildstage /root-layer/ /
