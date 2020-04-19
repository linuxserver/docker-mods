FROM lsiobase/alpine:3.11 as buildstage

ARG PS_VERSION

RUN \
 apk add --no-cache \
    curl && \
 if [ -z ${PS_VERSION+x} ]; then \
	PS_VERSION=$(curl -sX GET "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]' | awk '{print substr($1,2); }'); \
 fi && \
 mkdir -p /root-layer && \
 curl -o \
   /root-layer/powershell.deb -L \
   "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell_${PS_VERSION}-1.ubuntu.18.04_amd64.deb"

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
