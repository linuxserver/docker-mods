FROM ghcr.io/linuxserver/baseimage-alpine:3.13 as buildstage

ARG PS_VERSION

RUN \
  apk add --no-cache \
    curl \
    jq && \
  if [ -z ${PS_VERSION+x} ]; then \
    PS_VERSION=$(curl -sX GET "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" \
      | jq -r .tag_name | awk '{print substr($1,2); }'); \
  fi && \
  mkdir -p /root-layer/powershell && \
  curl -o \
    /root-layer/powershell/powershell_x86_64.tar.gz -L \
    "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-x64.tar.gz" && \
  curl -o \
    /root-layer/powershell/powershell_armv7l.tar.gz -L \
    "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-arm32.tar.gz" && \
  curl -o \
    /root-layer/powershell/powershell_aarch64.tar.gz -L \
    "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-arm64.tar.gz" && \
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
