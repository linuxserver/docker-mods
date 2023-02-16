## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage

ARG DOCKER_RELEASE
ARG COMPOSE_RELEASE

RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    git \
    go && \
  echo "**** retrieve latest version ****" && \
  if [ -z ${DOCKER_RELEASE+x} ]; then \
    DOCKER_RELEASE=$(curl -sX GET "https://api.github.com/repos/moby/moby/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]' \
      | sed 's|^v||'); \
  fi && \
  echo "**** grab docker ****" && \
  mkdir -p /root-layer/docker-tgz && \
  curl -fo \
    /root-layer/docker-tgz/docker_x86_64.tgz -L \
    "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_RELEASE}.tgz" && \
  curl -fo \
    /root-layer/docker-tgz/docker_armv7l.tgz -L \
    "https://download.docker.com/linux/static/stable/armhf/docker-${DOCKER_RELEASE}.tgz" && \
  curl -fo \
    /root-layer/docker-tgz/docker_aarch64.tgz -L \
    "https://download.docker.com/linux/static/stable/aarch64/docker-${DOCKER_RELEASE}.tgz" && \
  echo "**** retrieve latest compose version ****" && \
  if [ -z ${COMPOSE_RELEASE+x} ]; then \
    COMPOSE_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/compose/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]' \
      | sed 's|^v||'); \
  fi && \
  echo "**** grab compose ****" && \
  curl -fo \
    /root-layer/docker-tgz/docker-compose_x86_64 -L \
    "https://github.com/docker/compose/releases/download/v${COMPOSE_RELEASE}/docker-compose-linux-x86_64" && \
  curl -fo \
    /root-layer/docker-tgz/docker-compose_armv7l -L \
    "https://github.com/docker/compose/releases/download/v${COMPOSE_RELEASE}/docker-compose-linux-armv7" && \
  curl -fo \
    /root-layer/docker-tgz/docker-compose_aarch64 -L \
    "https://github.com/docker/compose/releases/download/v${COMPOSE_RELEASE}/docker-compose-linux-aarch64" && \
  echo "**** retrieve latest compose switch version ****" && \
  if [ -z ${SWITCH_RELEASE+x} ]; then \
    SWITCH_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/compose-switch/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]' \
      | sed 's|^v||'); \
  fi && \
  echo "**** grab compose switch ****" && \
  curl -fo \
    /root-layer/docker-tgz/compose-switch_x86_64 -L \
    "https://github.com/docker/compose-switch/releases/download/v${SWITCH_RELEASE}/docker-compose-linux-amd64" && \
  curl -fo \
    /root-layer/docker-tgz/compose-switch_aarch64 -L \
    "https://github.com/docker/compose-switch/releases/download/v${SWITCH_RELEASE}/docker-compose-linux-arm64" && \
  echo "**** compile compose switch on armhf ****" && \
  curl -fo \
    /tmp/compose-switch.tar.gz -L \
    "https://github.com/docker/compose-switch/archive/refs/tags/v${SWITCH_RELEASE}.tar.gz" && \
  mkdir -p /tmp/compose-switch && \
  tar xf \
    /tmp/compose-switch.tar.gz -C \
    /tmp/compose-switch --strip-components=1 && \
  cd /tmp/compose-switch && \
  CGO_ENABLED=0 GOOS=linux GOARCH=arm go build -ldflags="-s -w -X github.com/docker/compose-switch/internal.Version=${SWITCH_RELEASE}" -o /root-layer/docker-tgz/compose-switch_armv7l ./main.go && \
  echo "**** retrieve latest buildx version ****" && \
  BUILDX_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/buildx/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  echo "**** grab buildx ****" && \
  curl -fo \
    /root-layer/docker-tgz/docker-buildx_x86_64 -L \
    "https://github.com/docker/buildx/releases/download/${BUILDX_RELEASE}/buildx-${BUILDX_RELEASE}.linux-amd64" && \
  curl -fo \
    /root-layer/docker-tgz/docker-buildx_armv7l -L \
    "https://github.com/docker/buildx/releases/download/${BUILDX_RELEASE}/buildx-${BUILDX_RELEASE}.linux-arm-v7" && \
  curl -fo \
    /root-layer/docker-tgz/docker-buildx_aarch64 -L \
    "https://github.com/docker/buildx/releases/download/${BUILDX_RELEASE}/buildx-${BUILDX_RELEASE}.linux-arm64" && \
  chmod +x /root-layer/docker-tgz/* && \
  rm -rf /tmp/*
  


# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
