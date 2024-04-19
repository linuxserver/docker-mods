# syntax=docker/dockerfile:1

## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.19 as buildstage

ARG MOD_VERSION

RUN \
  mkdir -p \
    /root-layer && \
  if [[ -z "${MOD_VERSION}" ]]; then \
    MOD_VERSION=$(curl -sX GET "https://api.github.com/repos/kovidgoyal/calibre/releases/latest" \
      | jq -r '.tag_name'); \
  fi && \
  echo $MOD_VERSION > /root-layer/CALIBRE_RELEASE

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
