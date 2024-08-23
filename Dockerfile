# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.20 AS grab-stage

ARG MOD_VERSION

RUN \
  apk add --no-cache --upgrade \
    tar && \
  mkdir -p /root/defaults/nginx/proxy-confs && \
  if [[ -z "${MOD_VERSION}" ]]; then \
    MOD_VERSION=$(curl -fsSL https://api.github.com/repos/linuxserver/reverse-proxy-confs/commits/master | jq -r '.sha'); \
  fi && \
  curl -o \
    /tmp/proxy.tar.gz -L \
    "https://github.com/linuxserver/reverse-proxy-confs/archive/${MOD_VERSION}.tar.gz" && \
  tar xf \
    /tmp/proxy.tar.gz -C \
    /root/defaults/nginx/proxy-confs \
    --strip-components=1 \
    --exclude=reverse*/.editorconfig \
    --exclude=reverse*/.gitattributes \
    --exclude=reverse*/.github \
    --exclude=reverse*/.gitignore \
    --exclude=reverse*/LICENSE
# copy local files
COPY root/ root/

ADD https://raw.githubusercontent.com/linuxserver/docker-swag/master/root/defaults/nginx/proxy.conf.sample /root/defaults/nginx/proxy.conf.sample

FROM scratch

LABEL maintainer="Roxedus"

# copy proxy-confs
COPY --from=grab-stage root/ /
