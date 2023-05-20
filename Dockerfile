# syntax=docker/dockerfile:1

## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage

ARG MOD_VERSION

RUN \
  echo "**** install packages ****" && \
  if [ -z "${MOD_VERSION}" ]; then \
    MOD_VERSION=$(curl -sX GET "https://api.github.com/repos/intel/compute-runtime/releases/latest" | jq -r '.tag_name'); \
  fi && \
  COMP_RT_URLS=$(curl -sX GET "https://api.github.com/repos/intel/compute-runtime/releases/tags/${MOD_VERSION}" | jq -r '.body' | grep wget | grep -v ww47 | sed 's|wget ||g') && \
  echo "**** grab debs ****" && \
  mkdir -p /root-layer/opencl-intel && \
  for i in $COMP_RT_URLS; do \
    echo "**** downloading ${i%$'\r'} ****" && \
    curl -o /root-layer/opencl-intel/$(basename "${i%$'\r'}") \
      -L "${i%$'\r'}"; \
  done

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
