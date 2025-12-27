# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.23 as buildstage

ARG MOD_VERSION

RUN \
  echo "**** grab transmission trguing ****" && \
  mkdir -p /root-layer/themes && \
  if [ -z ${MOD_VERSION} ]; then \
    MOD_VERSION=$(curl -s "https://api.github.com/repos/openscopeproject/TrguiNG/releases/latest" \
    | jq -rc ".tag_name"); \
  fi && \
  curl -o \
    /tmp/trguing-web.zip -L \
    "https://github.com/openscopeproject/TrguiNG/releases/download/${MOD_VERSION}/trguing-web-${MOD_VERSION}.zip" && \
  mkdir -p /root-layer/themes/trguing && \
  unzip \
    /tmp/trguing-web.zip -d \
    /root-layer/themes/trguing

# copy local files
COPY root/ /root-layer/

# ## Single layer deployed image ##
FROM scratch

LABEL maintainer="Azlux"

# # Add files from buildstage
COPY --from=buildstage /root-layer/ /
