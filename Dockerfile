# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.20 as buildstage

ARG MOD_VERSION

RUN \
  if [ -z ${MOD_VERSION+x} ]; then \
    MOD_VERSION=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release?tag=stable \
      | sed 's|.*tag/v||g'); \
  fi && \
  mkdir -p /root-layer/powershell && \
  if [[ $(uname -m) == "x86_64" ]]; then \
    echo "Downloading x86_64 tarball" && \
    curl -o \
      /root-layer/powershell/powershell.tar.gz -L \
      "https://github.com/PowerShell/PowerShell/releases/download/v${MOD_VERSION}/powershell-${MOD_VERSION}-linux-x64.tar.gz"; \
  elif [[ $(uname -m) == "aarch64" ]]; then \
    echo "Downloading aarch64 tarball" && \
    curl -o \
      /root-layer/powershell/powershell.tar.gz -L \
      "https://github.com/PowerShell/PowerShell/releases/download/v${MOD_VERSION}/powershell-${MOD_VERSION}-linux-arm64.tar.gz"; \
  fi && \
  echo "******** run basic test to validate tarball *********" && \
  mkdir -p /tmp/powershell && \
  tar xzf /root-layer/powershell/powershell.tar.gz -C /tmp/powershell

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
