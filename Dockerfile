## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-ubuntu:focal as buildstage

ARG BUILD_DATE
ARG VERSION
ARG CALIBRE_RELEASE
ARG DEBIAN_FRONTEND="noninteractive"
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="chbmb"

RUN \
  echo "**** Install packages ****" && \
  apt-get update && \
  apt-get install -y \
    xz-utils && \
  echo "**** Fetch calibre bin ****" && \
  if [ -z ${CALIBRE_RELEASE+x} ]; then \
    CALIBRE_RELEASE=$(curl -sX GET "https://api.github.com/repos/kovidgoyal/calibre/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  CALIBRE_RELEASE=$(echo "${CALIBRE_RELEASE}" | sed 's/^v//g' ) && \ 
  mkdir -p \
    /root-layer/app/calibre && \
  curl -o \
    /tmp/calibre.txz -L \
    "https://download.calibre-ebook.com/${CALIBRE_RELEASE}/calibre-${CALIBRE_RELEASE}-x86_64.txz" && \
  tar xf \
    /tmp/calibre.txz \
    -C /root-layer/app/calibre

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
