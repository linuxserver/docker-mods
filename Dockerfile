# syntax=docker/dockerfile:1

# Build container
FROM ghcr.io/linuxserver/baseimage-alpine:3.18 AS buildstage

ARG MOD_VERSION

RUN \
  echo "**** retrieve latest version ****" && \
  if [[ -z "${MOD_VERSION}" ]]; then \
    MOD_VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest \
      | jq -rc ".tag_name"); \
  fi && \
  echo "**** grab binaries ****" && \
  mkdir -p /root-layer/cloudflared && \
  curl -fo \
    /root-layer/cloudflared/cloudflared-amd64 -L \
    "https://github.com/cloudflare/cloudflared/releases/download/${MOD_VERSION}/cloudflared-linux-amd64" && \
  curl -fo \
    /root-layer/cloudflared/cloudflared-arm64 -L \
    "https://github.com/cloudflare/cloudflared/releases/download/${MOD_VERSION}/cloudflared-linux-arm64" && \
  chmod +x /root-layer/cloudflared/*

COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="Spunkie"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
