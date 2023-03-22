## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage-x86_64

RUN \
  echo "**** install packages ****" && \
  apk add -U --update --no-cache --virtual=build-dependencies \
    autoconf \
    automake \
    build-base && \
  echo "**** install par2cmdline-turbo from source ****" && \
  mkdir /tmp/par2cmdline && \
  curl -o \
    /tmp/par2cmdline.tar.gz -L \
    "https://github.com/animetosho/par2cmdline-turbo/archive/refs/heads/turbo.tar.gz" && \  
  tar xf \
    /tmp/par2cmdline.tar.gz -C \
    /tmp/par2cmdline --strip-components=1 && \
  cd /tmp/par2cmdline && \
  ./automake.sh && \
  ./configure && \
  make && \
  make check && \
  make install DESTDIR=/root-layer

## Buildstage ##
FROM --platform=aarch64 ghcr.io/linuxserver/baseimage-alpine:arm64v8-3.17 as buildstage-aarch64

RUN \
  echo "**** install packages ****" && \
  apk add -U --update --no-cache --virtual=build-dependencies \
    autoconf \
    automake \
    build-base \
    linux-headers && \
  echo "**** install par2cmdline-turbo from source ****" && \
  mkdir /tmp/par2cmdline && \
  curl -o \
    /tmp/par2cmdline.tar.gz -L \
    "https://github.com/animetosho/par2cmdline-turbo/archive/refs/heads/turbo.tar.gz" && \  
  tar xf \
    /tmp/par2cmdline.tar.gz -C \
    /tmp/par2cmdline --strip-components=1 && \
  cd /tmp/par2cmdline && \
  ./automake.sh && \
  ./configure && \
  make && \
  make check && \
  make install DESTDIR=/root-layer


## Single layer deployed image ##
FROM scratch

LABEL maintainer="thespad"

# Add files from buildstage
COPY --from=buildstage-x86_64 /root-layer/ /par2cmdline-turbo/x86_64
COPY --from=buildstage-aarch64 /root-layer/ /par2cmdline-turbo/aarch64
