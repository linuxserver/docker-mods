FROM ghcr.io/linuxserver/baseimage-alpine:3.12 as buildstage

ARG DOTNET_VERSIONS

RUN \
 apk add --no-cache \
    curl \
    jq && \
 DOTNET_JSON=$(curl -sX GET "https://raw.githubusercontent.com/dotnet/core/master/release-notes/releases-index.json") && \
 if [ -z ${DOTNET_VERSIONS+x} ]; then \
    DOTNET_VERSIONS=$(echo "$DOTNET_JSON" | jq -r '."releases-index"[] | select(."support-phase"=="lts" or ."support-phase"=="current") | ."latest-sdk"' | tr '\n' ' ' | head -c -1); \
 fi && \
 mkdir -p /root-layer/dotnet && \
 echo "$DOTNET_VERSIONS" > /root-layer/dotnet/versions.txt && \
 echo "versions are ${DOTNET_VERSIONS}" && \
 for i in $DOTNET_VERSIONS; do \
    echo "processing version ${i}" && \
    DOTNET_RELEASE_URL=$(echo "${DOTNET_JSON}" | jq -r ".\"releases-index\"[] | select(.\"latest-sdk\"==\"${i}\") | .\"releases.json\"") && \
    DOTNET_RELEASE_JSON=$(curl -sX GET "${DOTNET_RELEASE_URL}") && \
    AMD64_URL=$(echo "${DOTNET_RELEASE_JSON}" | jq -r ".releases[] | select(.sdk.version==\"${i}\") | .sdk.files[] | select(.name | contains(\"linux-x64\")) | .url") && \
    ARM32_URL=$(echo "${DOTNET_RELEASE_JSON}" | jq -r ".releases[] | select(.sdk.version==\"${i}\") | .sdk.files[] | select(.name | contains(\"linux-arm.\")) | .url") && \
    ARM64_URL=$(echo "${DOTNET_RELEASE_JSON}" | jq -r ".releases[] | select(.sdk.version==\"${i}\") | .sdk.files[] | select(.name | contains(\"linux-arm64\")) | .url") && \
    curl -fS --retry 3 --retry-connrefused -o \
        /root-layer/dotnet/dotnetsdk_"${i}"_x86_64.tar.gz -L \
        "${AMD64_URL}" && \
    curl -fS --retry 3 --retry-connrefused -o \
        /root-layer/dotnet/dotnetsdk_"${i}"_armv7l.tar.gz -L \
        "${ARM32_URL}" && \
    curl -fS --retry 3 --retry-connrefused -o \
        /root-layer/dotnet/dotnetsdk_"${i}"_aarch64.tar.gz -L \
        "${ARM64_URL}"; \
done

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="aptalca"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
