# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage

ARG MOD_VERSION

RUN \
  if [ -z "${MOD_VERSION}" ]; then \
    MOD_VERSION=$(curl -sL https://julialang.org/downloads/ \
      | sed 's|.*Current stable release: v||' \
      | sed 's| (.*||'); \
  fi && \
  JULIA_MIN_VERSION=$(echo "${MOD_VERSION}" | cut -d. -f 1,2) && \
  mkdir -p /root-layer/julia-bins && \
  echo "**** Downloading x86_64 binary ****" && \
  curl -fL "https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_MIN_VERSION}/julia-${MOD_VERSION}-linux-x86_64.tar.gz" -o \
    "/root-layer/julia-bins/julia-x86_64.tar.gz" && \
  echo "**** Downloading aarch64 binary ****" && \
  curl -fL "https://julialang-s3.julialang.org/bin/linux/aarch64/${JULIA_MIN_VERSION}/julia-${MOD_VERSION}-linux-aarch64.tar.gz" -o \
    "/root-layer/julia-bins/julia-aarch64.tar.gz"

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="MateoPeri"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
