# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.23 AS buildstage

ARG MOD_VERSION

RUN \
  echo "**** retrieve latest docker and compose versions ****" && \
  if [ -z "${MOD_VERSION}" ]; then \
    DOCKER_RELEASE=$(curl -sX GET "https://api.github.com/repos/moby/moby/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]' \
      | sed 's|^docker-||' \
      | sed 's|^v||'); \
    COMPOSE_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/compose/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]' \
      | sed 's|^v||'); \
  else \
    DOCKER_RELEASE=$(echo "${MOD_VERSION}" | sed 's|-.*||'); \
    COMPOSE_RELEASE=$(echo "${MOD_VERSION}" | sed 's|.*-||'); \
  fi && \
  echo "**** retrieve latest compose switch version ****" && \
  if [ -z ${SWITCH_RELEASE+x} ]; then \
    SWITCH_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/compose-switch/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]' \
      | sed 's|^v||'); \
  fi && \
  echo "**** retrieve latest buildx version ****" && \
  if [ -z ${BUILDX_RELEASE+x} ]; then \
    BUILDX_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/buildx/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  mkdir -p \
    /root-layer/docker-bins \
    /tmp/docker && \
  if [ $(uname -m) = "x86_64" ]; then \
    echo "**** grab x86_64 tarballs and binaries ****" && \
    curl -fo \
      /tmp/docker.tgz -L \
      "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_RELEASE}.tgz" && \
    tar xf \
      /tmp/docker.tgz -C \
      /tmp/docker --strip-components=1 && \
    cp /tmp/docker/docker /root-layer/docker-bins/docker && \
    curl -fo \
      /root-layer/docker-bins/docker-compose -L \
      "https://github.com/docker/compose/releases/download/v${COMPOSE_RELEASE}/docker-compose-linux-x86_64" && \
    curl -fo \
      /root-layer/docker-bins/compose-switch -L \
      "https://github.com/docker/compose-switch/releases/download/v${SWITCH_RELEASE}/docker-compose-linux-amd64" && \
    curl -fo \
      /root-layer/docker-bins/docker-buildx -L \
      "https://github.com/docker/buildx/releases/download/${BUILDX_RELEASE}/buildx-${BUILDX_RELEASE}.linux-amd64"; \
  elif [ $(uname -m) = "aarch64" ]; then \
    echo "**** grab aarch64 tarballs and binaries ****" && \
    curl -fo \
      /tmp/docker.tgz -L \
      "https://download.docker.com/linux/static/stable/aarch64/docker-${DOCKER_RELEASE}.tgz" && \
    tar xf \
      /tmp/docker.tgz -C \
      /tmp/docker --strip-components=1 && \
    cp /tmp/docker/docker /root-layer/docker-bins/docker && \
    curl -fo \
      /root-layer/docker-bins/docker-compose -L \
      "https://github.com/docker/compose/releases/download/v${COMPOSE_RELEASE}/docker-compose-linux-aarch64" && \
    curl -fo \
      /root-layer/docker-bins/compose-switch -L \
      "https://github.com/docker/compose-switch/releases/download/v${SWITCH_RELEASE}/docker-compose-linux-arm64" && \
    curl -fo \
      /root-layer/docker-bins/docker-buildx -L \
      "https://github.com/docker/buildx/releases/download/${BUILDX_RELEASE}/buildx-${BUILDX_RELEASE}.linux-arm64"; \
  fi && \
  chmod +x /root-layer/docker-bins/* && \
  rm -rf /tmp/*

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
