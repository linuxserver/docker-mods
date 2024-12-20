# syntax=docker/dockerfile:1

# Build container
FROM ghcr.io/linuxserver/baseimage-alpine:3.21 AS buildstage

ARG MOD_VERSION

RUN \
  echo "**** retrieve latest version ****" && \
  if [[ -z "${MOD_VERSION}" ]]; then \
    MOD_VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest \
      | jq -rc ".tag_name"); \
  fi && \
  mkdir -p /root-layer/cloudflared && \
  if [ $(uname -m) = "x86_64" ]; then \
    echo "**** Downloading x86_64 binaries ****" && \
    curl -fo \
      /root-layer/cloudflared/cloudflared -L \
      "https://github.com/cloudflare/cloudflared/releases/download/${MOD_VERSION}/cloudflared-linux-amd64" && \
    curl -fo \
      /root-layer/cloudflared/yq -L \
      "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"; \
  elif [ $(uname -m) = "aarch64" ]; then \
    echo "**** Downloading aarch64 binaries ****" && \
    curl -fo \
      /root-layer/cloudflared/cloudflared -L \
      "https://github.com/cloudflare/cloudflared/releases/download/${MOD_VERSION}/cloudflared-linux-arm64" && \
    curl -fo \
      /root-layer/cloudflared/yq -L \
      "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64"; \
  fi && \
  chmod +x /root-layer/cloudflared/*

COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="Spunkie"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
