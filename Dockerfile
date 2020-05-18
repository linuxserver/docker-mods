FROM lsiobase/alpine:3.11 as buildstage

ARG PS_VERSION

RUN \
 apk add --no-cache \
    curl && \
 if [ -z ${PS_VERSION+x} ]; then \
	PS_VERSION=$(curl -sX GET "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]' | awk '{print substr($1,2); }'); \
 fi && \
 mkdir -p /root-layer/powershell && \
 curl -o \
   /root-layer/powershell/powershell_x86_64.tar.gz -L \
   "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell_${PS_VERSION}-linux-x64.tar.gz" && \
 curl -o \
   /root-layer/powershell/powershell_armv7l.tar.gz -L \
   "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell_${PS_VERSION}-linux-arm32.tar.gz" && \
 curl -o \
   /root-layer/powershell/powershell_aarch64.tar.gz -L \
   "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell_${PS_VERSION}-linux-arm64.tar.gz"

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
