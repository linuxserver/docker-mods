# syntax=docker/dockerfile:1

## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.22 AS buildstage

ARG GIT_HASH=902a4ef

# copy local files
COPY root/ /root-layer/

RUN \
  echo "**** install build packages ****" && \h
  apk add --no-cache \
    curl build-base && \
  echo "**** get heyu source ****" && \
  mkdir -p /build && \
  cd /build && \
  curl -LsSo heyu.zip https://github.com/HeyuX10Automation/heyu/archive/${GIT_HASH}.zip && \
  unzip heyu.zip && \
  mv heyu-* heyu && \
  cd heyu && \
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