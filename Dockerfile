# syntax=docker/dockerfile:1

## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.20 AS buildstage

ARG MOD_VERSION

RUN \
  mkdir -p \
    /root-layer && \
  if [[ -z "${MOD_VERSION}" ]]; then \
    MOD_VERSION=$(curl -sX GET "https://api.github.com/repos/kovidgoyal/calibre/releases/latest" \
      | jq -r '.tag_name'); \
  fi && \
  if [ "$(uname -m)" == "x86_64" ]; then \
    curl -o \
        /root-layer/calibre.txz -L \
        "https://download.calibre-ebook.com/${MOD_VERSION:1}/calibre-${MOD_VERSION:1}-x86_64.txz"; \
  elif [ "$(uname -m)" == "aarch64" ]; then \
    curl -o \
        /root-layer/calibre.txz -L \
        "https://download.calibre-ebook.com/${MOD_VERSION:1}/calibre-${MOD_VERSION:1}-arm64.txz"; \
  fi && \
  echo $MOD_VERSION > /root-layer/CALIBRE_RELEASE

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
