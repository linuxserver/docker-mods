## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-ubuntu:focal as buildstage

ARG BUILD_DATE
ARG VERSION
ARG CALIBRE_RELEASE
ARG DEBIAN_FRONTEND="noninteractive"
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="chbmb"

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
