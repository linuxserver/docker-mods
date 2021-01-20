ARG COMPOSE_TAG="latest"
ARG COMPOSE_ALPINE_TAG="alpine"

FROM ghcr.io/linuxserver/docker-compose:amd64-${COMPOSE_TAG} as compose-amd64
FROM ghcr.io/linuxserver/docker-compose:arm32v7-${COMPOSE_TAG} as compose-arm32
FROM ghcr.io/linuxserver/docker-compose:arm64v8-${COMPOSE_TAG} as compose-arm64
FROM ghcr.io/linuxserver/docker-compose:amd64-alpine-${COMPOSE_ALPINE_TAG} as compose-alpine-amd64
FROM ghcr.io/linuxserver/docker-compose:arm32v7-alpine-${COMPOSE_ALPINE_TAG} as compose-alpine-arm32
FROM ghcr.io/linuxserver/docker-compose:arm64v8-alpine-${COMPOSE_ALPINE_TAG} as compose-alpine-arm64

FROM ghcr.io/linuxserver/baseimage-alpine:3.12 as buildstage

COPY --from=compose-amd64 /usr/local/bin/docker-compose /root-layer/docker-compose-ubuntu/docker-compose_x86_64
COPY --from=compose-amd64 /usr/local/bin/docker /root-layer/docker-compose-ubuntu/docker_x86_64
COPY --from=compose-arm32 /usr/local/bin/docker-compose /root-layer/docker-compose-ubuntu/docker-compose_armv7l
COPY --from=compose-arm32 /usr/local/bin/docker /root-layer/docker-compose-ubuntu/docker_armv7l
COPY --from=compose-arm64 /usr/local/bin/docker-compose /root-layer/docker-compose-ubuntu/docker-compose_aarch64
COPY --from=compose-arm64 /usr/local/bin/docker /root-layer/docker-compose-ubuntu/docker_aarch64
COPY --from=compose-alpine-amd64 /usr/local/bin/docker-compose /root-layer/docker-compose-alpine/docker-compose_x86_64
COPY --from=compose-alpine-amd64 /usr/local/bin/docker /root-layer/docker-compose-alpine/docker_x86_64
COPY --from=compose-alpine-arm32 /usr/local/bin/docker-compose /root-layer/docker-compose-alpine/docker-compose_armv7l
COPY --from=compose-alpine-arm32 /usr/local/bin/docker /root-layer/docker-compose-alpine/docker_armv7l
COPY --from=compose-alpine-arm64 /usr/local/bin/docker-compose /root-layer/docker-compose-alpine/docker-compose_aarch64
COPY --from=compose-alpine-arm64 /usr/local/bin/docker /root-layer/docker-compose-alpine/docker_aarch64
COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
