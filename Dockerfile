## Buildstage ##
ARG DOCKER_RELEASE
ARG COMPOSE_TAG="latest"
ARG COMPOSE_ALPINE_TAG="alpine"

FROM ghcr.io/linuxserver/docker-compose:amd64-${COMPOSE_TAG} as compose-amd64
FROM ghcr.io/linuxserver/docker-compose:arm32v7-${COMPOSE_TAG} as compose-arm32
FROM ghcr.io/linuxserver/docker-compose:arm64v8-${COMPOSE_TAG} as compose-arm64
FROM ghcr.io/linuxserver/docker-compose:amd64-${COMPOSE_ALPINE_TAG} as compose-alpine-amd64
FROM ghcr.io/linuxserver/docker-compose:arm32v7-${COMPOSE_ALPINE_TAG} as compose-alpine-arm32
FROM ghcr.io/linuxserver/docker-compose:arm64v8-${COMPOSE_ALPINE_TAG} as compose-alpine-arm64

FROM ghcr.io/linuxserver/baseimage-alpine:3.13 as buildstage

RUN \
 echo "**** install packages ****" && \
 apk add --no-cache \
	curl && \
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
	"https://download.docker.com/linux/static/stable/aarch64/docker-${DOCKER_RELEASE}.tgz"

# copy local files
COPY --from=compose-amd64 /usr/local/bin/docker-compose /root-layer/docker-compose-ubuntu/docker-compose_x86_64
COPY --from=compose-arm32 /usr/local/bin/docker-compose /root-layer/docker-compose-ubuntu/docker-compose_armv7l
COPY --from=compose-arm64 /usr/local/bin/docker-compose /root-layer/docker-compose-ubuntu/docker-compose_aarch64
COPY --from=compose-alpine-amd64 /usr/local/bin/docker-compose /root-layer/docker-compose-alpine/docker-compose_x86_64
COPY --from=compose-alpine-arm32 /usr/local/bin/docker-compose /root-layer/docker-compose-alpine/docker-compose_armv7l
COPY --from=compose-alpine-arm64 /usr/local/bin/docker-compose /root-layer/docker-compose-alpine/docker-compose_aarch64
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
