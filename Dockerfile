# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage

ARG MOD_VERSION

RUN \
  if [ -z ${MOD_VERSION+x} ]; then \
    MOD_VERSION=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release?tag=stable \
      | sed 's|.*tag/v||g'); \
  fi && \
  mkdir -p /root-layer/powershell && \
  curl -o \
    /root-layer/powershell/powershell_x86_64.tar.gz -L \
    "https://github.com/PowerShell/PowerShell/releases/download/v${MOD_VERSION}/powershell-${MOD_VERSION}-linux-x64.tar.gz" && \
  curl -o \
    /root-layer/powershell/powershell_armv7l.tar.gz -L \
    "https://github.com/PowerShell/PowerShell/releases/download/v${MOD_VERSION}/powershell-${MOD_VERSION}-linux-arm32.tar.gz" && \
  curl -o \
    /root-layer/powershell/powershell_aarch64.tar.gz -L \
    "https://github.com/PowerShell/PowerShell/releases/download/v${MOD_VERSION}/powershell-${MOD_VERSION}-linux-arm64.tar.gz" && \
  echo "******** run basic test to validate tarballs *********" && \
  for i in x86_64 armv7l aarch64; do \
    mkdir -p "/tmp/${i}"; \
    tar xzf "/root-layer/powershell/powershell_${i}.tar.gz" -C "/tmp/${i}"; \
  done

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
