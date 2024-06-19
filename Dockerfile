# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.20 as buildstage

ARG MOD_VERSION

RUN \
  DOTNET_JSON=$(curl -sX GET "https://raw.githubusercontent.com/dotnet/core/master/release-notes/releases-index.json") && \
  if [ -z ${MOD_VERSION+x} ]; then \
    MOD_VERSION=$(echo "$DOTNET_JSON" | jq -r '."releases-index"[] | select(."support-phase"=="active" or ."support-phase"=="maintenance") | ."latest-sdk"' | tr '\n' '_' | head -c -1); \
  fi && \
  DOTNET_VERSIONS="${MOD_VERSION//_/ }" && \
  mkdir -p /root-layer/dotnet && \
  echo "$DOTNET_VERSIONS" > /root-layer/dotnet/versions.txt && \
  echo "versions are ${DOTNET_VERSIONS}" && \
  for i in $DOTNET_VERSIONS; do \
    DOTNET_RELEASE_URL=$(echo "${DOTNET_JSON}" | jq -r ".\"releases-index\"[] | select(.\"latest-sdk\"==\"${i}\") | .\"releases.json\"") && \
    DOTNET_RELEASE_JSON=$(curl -fSsLX GET "${DOTNET_RELEASE_URL}") && \
    if [ $(uname -m) = "x86_64" ]; then \
      echo "**** Downloading x86_64 tarball for version ${i} ****" && \
      TARBALL_URL=$(echo "${DOTNET_RELEASE_JSON}" | jq -r ".releases[] | select(.sdk.version==\"${i}\") | .sdk.files[] | select(.name | contains(\"linux-x64.tar.gz\")) | .url"); \
    elif [ $(uname -m) = "aarch64" ]; then \
      echo "**** Downloading aarch64 tarball for version ${i} ****" && \
      TARBALL_URL=$(echo "${DOTNET_RELEASE_JSON}" | jq -r ".releases[] | select(.sdk.version==\"${i}\") | .sdk.files[] | select(.name | contains(\"linux-arm64.tar.gz\")) | .url"); \
    fi && \
    curl -fSL --retry 3 --retry-connrefused -o \
      /root-layer/dotnet/dotnetsdk_"${i}".tar.gz -L \
      "${TARBALL_URL}" || exit 1; \
  done

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
