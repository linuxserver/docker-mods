# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage

ARG MOD_VERSION

RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    git \
    go && \
  echo "**** retrieve latest version ****" && \
  if [[ -z "${MOD_VERSION+x}" ]]; then \
    DOCKER_RELEASE=$(curl -sX GET "https://api.github.com/repos/moby/moby/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]' \
      | sed 's|^v||'); \
    COMPOSE_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/compose/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]' \
      | sed 's|^v||'); \
  else \
    DOCKER_RELEASE=$(echo "${MOD_VERSION}" | sed 's|-.*||'); \
    COMPOSE_RELEASE=$(echo "${MOD_VERSION}" | sed 's|.*-||'); \
  fi && \
  echo "**** grab docker ****" && \
  mkdir -p \
    /root-layer/docker-bins \
    /tmp/docker_x86_64 \
    /tmp/docker_aarch64 && \
  curl -fo \
    /tmp/docker_x86_64.tgz -L \
    "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_RELEASE}.tgz" && \
  tar xf \
    /tmp/docker_x86_64.tgz -C \
    /tmp/docker_x86_64 --strip-components=1 && \
  cp /tmp/docker_x86_64/docker /root-layer/docker-bins/docker_x86_64 && \
  curl -fo \
    /tmp/docker_aarch64.tgz -L \
    "https://download.docker.com/linux/static/stable/aarch64/docker-${DOCKER_RELEASE}.tgz" && \
  tar xf \
    /tmp/docker_aarch64.tgz -C \
    /tmp/docker_aarch64 --strip-components=1 && \
  cp /tmp/docker_aarch64/docker /root-layer/docker-bins/docker_aarch64 && \
  echo "**** grab compose ****" && \
  curl -fo \
    /root-layer/docker-bins/docker-compose_x86_64 -L \
    "https://github.com/docker/compose/releases/download/v${COMPOSE_RELEASE}/docker-compose-linux-x86_64" && \
  curl -fo \
    /root-layer/docker-bins/docker-compose_aarch64 -L \
    "https://github.com/docker/compose/releases/download/v${COMPOSE_RELEASE}/docker-compose-linux-aarch64" && \
  echo "**** retrieve latest compose switch version ****" && \
  if [ -z ${SWITCH_RELEASE+x} ]; then \
    SWITCH_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/compose-switch/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]' \
      | sed 's|^v||'); \
  fi && \
  echo "**** grab compose switch ****" && \
  curl -fo \
    /root-layer/docker-bins/compose-switch_x86_64 -L \
    "https://github.com/docker/compose-switch/releases/download/v${SWITCH_RELEASE}/docker-compose-linux-amd64" && \
  curl -fo \
    /root-layer/docker-bins/compose-switch_aarch64 -L \
    "https://github.com/docker/compose-switch/releases/download/v${SWITCH_RELEASE}/docker-compose-linux-arm64" && \
  echo "**** retrieve latest buildx version ****" && \
  if [ -z ${BUILDX_RELEASE+x} ]; then \
    BUILDX_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/buildx/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  echo "**** grab buildx plugin ****" && \
  curl -fo \
    /root-layer/docker-bins/docker-buildx_x86_64 -L \
    "https://github.com/docker/buildx/releases/download/${BUILDX_RELEASE}/buildx-${BUILDX_RELEASE}.linux-amd64" && \
  curl -fo \
    /root-layer/docker-bins/docker-buildx_aarch64 -L \
    "https://github.com/docker/buildx/releases/download/${BUILDX_RELEASE}/buildx-${BUILDX_RELEASE}.linux-arm64" && \
  chmod +x /root-layer/docker-bins/* && \
  rm -rf /tmp/*

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
