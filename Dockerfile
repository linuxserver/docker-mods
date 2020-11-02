## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.12 as buildstage

# Build arguments
ARG VERSION

# Add version number for use in container init script
RUN mkdir -p /root-layer/etc && \
  echo "$VERSION" > /root-layer/etc/version.tc989

# Stage local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="TheCaptain989"

# Copy files from buildstage
COPY --from=buildstage /root-layer/ /
