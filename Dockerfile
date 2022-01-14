FROM ghcr.io/linuxserver/baseimage-alpine:3.15 as build-stage

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

FROM scratch

LABEL maintainer="quietsy"

# copy local files
COPY root/ /
COPY --from=build-stage /build/ /
