FROM lsiobase/alpine:3.11 as buildstage

ARG COMPOSE_VERSION

RUN \
 apk add --no-cache \
    curl && \
 if [ -z ${COMPOSE_VERSION+x} ]; then \
	COMPOSE_VERSION=$(curl -sX GET "https://api.github.com/repos/docker/compose/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && \
 mkdir -p /root-layer && \
 curl -o \
   /root-layer/docker-compose -L \
   "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-Linux-x86_64" && \
 chmod +x /root-layer/docker-compose

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
