# syntax=docker/dockerfile:1

## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.19 as buildstage

ARG MOD_VERSION

RUN \
  echo "**** retrieve latest version ****" && \
  if [ -z "${MOD_VERSION+x}" ]; then \
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
  echo "**** retrieve latest compose switch version ****" && \
  SWITCH_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/compose-switch/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]' \
    | sed 's|^v||') && \
  echo "**** retrieve latest buildx version ****" && \
  BUILDX_RELEASE=$(curl -sX GET "https://api.github.com/repos/docker/buildx/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  mkdir -p /root-layer/docker-tgz && \
  if [ $(uname -m) = "x86_64" ]; then \
    echo "**** grab x86_64 tarballs and binaries ****" && \
    curl -fo \
      /root-layer/docker-tgz/docker.tgz -L \
      "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_RELEASE}.tgz" && \
    curl -fo \
      /root-layer/docker-tgz/docker-compose -L \
      "https://github.com/docker/compose/releases/download/v${COMPOSE_RELEASE}/docker-compose-linux-x86_64" && \
    curl -fo \
      /root-layer/docker-tgz/compose-switch -L \
      "https://github.com/docker/compose-switch/releases/download/v${SWITCH_RELEASE}/docker-compose-linux-amd64" && \
    curl -fo \
      /root-layer/docker-tgz/docker-buildx -L \
      "https://github.com/docker/buildx/releases/download/${BUILDX_RELEASE}/buildx-${BUILDX_RELEASE}.linux-amd64"; \
  elif [ $(uname -m) = "aarch64" ]; then \
    echo "**** grab aarch64 tarballs and binaries ****" && \
    curl -fo \
      /root-layer/docker-tgz/docker.tgz -L \
      "https://download.docker.com/linux/static/stable/aarch64/docker-${DOCKER_RELEASE}.tgz" && \
    curl -fo \
      /root-layer/docker-tgz/docker-compose -L \
      "https://github.com/docker/compose/releases/download/v${COMPOSE_RELEASE}/docker-compose-linux-aarch64" && \
    curl -fo \
      /root-layer/docker-tgz/compose-switch -L \
      "https://github.com/docker/compose-switch/releases/download/v${SWITCH_RELEASE}/docker-compose-linux-arm64" && \
    curl -fo \
      /root-layer/docker-tgz/docker-buildx -L \
      "https://github.com/docker/buildx/releases/download/${BUILDX_RELEASE}/buildx-${BUILDX_RELEASE}.linux-arm64"; \
  fi && \
  chmod +x /root-layer/docker-tgz/* && \
  rm -rf /tmp/*


# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
