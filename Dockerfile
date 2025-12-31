# syntax=docker/dockerfile:1

## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.23 AS buildstage

ARG MOD_VERSION

RUN \
  echo "**** install packages ****" && \
  if [ -z "${MOD_VERSION}" ]; then \
    MOD_VERSION=$(curl -sfX GET "https://api.github.com/repos/intel/compute-runtime/releases/latest" | jq -r '.tag_name'); \
  fi && \
  COMP_RT_URLS_LEGACY1=$(curl -sfX GET "https://api.github.com/repos/intel/compute-runtime/releases/tags/24.35.30872.22" | jq -r '.body' | grep wget | grep -v .sum | grep -v .ddeb | grep -v zero-gpu_ | grep -v opencl-icd_ | sed 's|wget ||g') && \
  echo "**** grab legacy1 debs ****" && \
  mkdir -p /root-layer/opencl-intel-legacy1 && \
  for i in $COMP_RT_URLS_LEGACY1; do \
    echo "**** downloading ${i%$'\r'} ****" && \
    curl -fS --retry 3 --retry-connrefused -o \
      /root-layer/opencl-intel-legacy1/$(basename "${i%$'\r'}") -L \
      "${i%$'\r'}" || exit 1; \
  done && \
  COMP_RT_URLS=$(curl -sfX GET "https://api.github.com/repos/intel/compute-runtime/releases/tags/${MOD_VERSION}" | jq -r '.body' | grep wget | grep -v .sum | grep -v .ddeb | sed 's|wget ||g') && \
  if [ -z "${COMP_RT_URLS}" ]; then \
    echo "**** No download URLs found in release, checking artifacts ****"; \
    COMP_RT_URLS=$(curl -sfX GET "https://api.github.com/repos/intel/compute-runtime/releases/tags/${MOD_VERSION}" | jq -r '.assets[].browser_download_url' | grep -v .sum | grep -v .ddeb); \
    IGC_VERSION=$(curl -sfX GET "https://api.github.com/repos/intel/intel-graphics-compiler/releases/latest" | jq -r '.tag_name'); \
    COMP_RT_URLS="${COMP_RT_URLS} $(curl -sfX GET https://api.github.com/repos/intel/intel-graphics-compiler/releases/tags/${IGC_VERSION} | jq -r '.assets[].browser_download_url' | grep -v devel)"; \
  fi && \
  echo "**** grab latest debs ****" && \
  mkdir -p /root-layer/opencl-intel && \
  for i in $COMP_RT_URLS; do \
    echo "**** downloading ${i%$'\r'} ****" && \
    curl -fS --retry 3 --retry-connrefused -o \
      /root-layer/opencl-intel/$(basename "${i%$'\r'}") -L \
      "${i%$'\r'}" || exit 1; \
  done

# copy local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
