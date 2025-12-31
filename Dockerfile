# syntax=docker/dockerfile:1

## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.22 AS buildstage

ARG GIT_HASH=902a4ef

# copy local files
COPY root/ /root-layer/

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache \
    curl build-base && \
  echo "**** get heyu source ****" && \
  mkdir -p /build && \
  cd /build && \
  curl -LsSo heyu.tar.gz https://github.com/HeyuX10Automation/heyu/archive/${GIT_HASH}.tar.gz && \
  tar --strip-components=1 -xf heyu.tar.gz && \
  echo "**** building heyu ****" && \
  ./configure --sysconfdir=/config/heyu/ && \
  make && \
  make install prefix=/root-layer sysconfdir=/root-layer/defaults && \
  cd /

## Single layer deployed image ##
FROM scratch

LABEL maintainer="dcflachs"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /