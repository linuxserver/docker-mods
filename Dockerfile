FROM ghcr.io/linuxserver/baseimage-alpine:3.15 as buildstage

ARG JULIA_VERSION

RUN \
  apk add --no-cache \
    curl \
    jq && \
  if [ -z "${JULIA_VERSION}" ]; then \
    JULIA_VERSION=$(curl -sX GET "https://api.github.com/repos/JuliaLang/julia/releases/latest" \
    | jq -r '. | .tag_name' \
    | sed 's|^v||'); \
  fi && \
  JULIA_MIN_VERSION=$(echo "${JULIA_VERSION}" | cut -d. -f 1,2) && \
  mkdir -p /root-layer/julia-bins && \
  echo "**** Downloading x86_64 binary ****" && \
  curl -fL "https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_MIN_VERSION}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" -o \
    "/root-layer/julia-bins/julia-x86_64.tar.gz" && \
  echo "**** Downloading armv7l binary ****" && \
  curl -fL "https://julialang-s3.julialang.org/bin/linux/armv7l/${JULIA_MIN_VERSION}/julia-${JULIA_VERSION}-linux-armv7l.tar.gz" -o \
    "/root-layer/julia-bins/julia-armv7l.tar.gz" && \
  echo "**** Downloading aarch64 binary ****" && \
  curl -fL "https://julialang-s3.julialang.org/bin/linux/aarch64/${JULIA_MIN_VERSION}/julia-${JULIA_VERSION}-linux-aarch64.tar.gz" -o \
    "/root-layer/julia-bins/julia-aarch64.tar.gz"

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="MateoPeri"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
