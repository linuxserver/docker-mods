FROM ghcr.io/linuxserver/baseimage-alpine:amd64-3.15 as build-stage-amd64

RUN \
  echo "**** install packages ****" && \
  apk add -U --update --no-cache --virtual=build-dependencies \
    autoconf \
    automake \
    build-base \
    git \
    glib-dev \
    libmaxminddb-dev \
    ncurses-dev && \
  mkdir -p /build && \  
  mkdir -p /goaccess && \  
  echo "**** build goaccess ****" && \  
  git clone --shallow-submodules --recurse-submodules https://github.com/allinurl/goaccess.git /goaccess && cd /goaccess && \
  autoreconf -fiv && \
  ./configure --enable-utf8 --enable-geoip=mmdb && \
  make DESTDIR="/build" install && \  
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /goaccess/* \
    /tmp/*

FROM ghcr.io/linuxserver/baseimage-alpine:arm32v7-3.15 as build-stage-arm32v7

RUN \
  echo "**** install packages ****" && \
  apk add -U --update --no-cache --virtual=build-dependencies \
    autoconf \
    automake \
    build-base \
    git \
    glib-dev \
    libmaxminddb-dev \
    ncurses-dev && \
  mkdir -p /build && \  
  mkdir -p /goaccess && \  
  echo "**** build goaccess ****" && \  
  git clone --shallow-submodules --recurse-submodules https://github.com/allinurl/goaccess.git /goaccess && cd /goaccess && \
  autoreconf -fiv && \
  ./configure --enable-utf8 --enable-geoip=mmdb && \
  make DESTDIR="/build" install && \  
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /goaccess/* \
    /tmp/*

FROM ghcr.io/linuxserver/baseimage-alpine:arm64v8-3.15 as build-stage-arm64v8

RUN \
  echo "**** install packages ****" && \
  apk add -U --update --no-cache --virtual=build-dependencies \
    autoconf \
    automake \
    build-base \
    git \
    glib-dev \
    libmaxminddb-dev \
    ncurses-dev && \
  mkdir -p /build && \  
  mkdir -p /goaccess && \  
  echo "**** build goaccess ****" && \  
  git clone --shallow-submodules --recurse-submodules https://github.com/allinurl/goaccess.git /goaccess && cd /goaccess && \
  autoreconf -fiv && \
  ./configure --enable-utf8 --enable-geoip=mmdb && \
  make DESTDIR="/build" install && \  
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /goaccess/* \
    /tmp/*

FROM scratch as build-stage-consolidate

COPY --from=build-stage-amd64 /build/ /goaccess/x86_64/
COPY --from=build-stage-arm32v7 /build/ /goaccess/armv7l/
COPY --from=build-stage-arm64v8 /build/ /goaccess/aarch64/
COPY root/ /

FROM scratch

LABEL maintainer="quietsy"

# copy local files
COPY --from=build-stage-consolidate / /
