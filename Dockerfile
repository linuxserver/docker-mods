# syntax=docker/dockerfile:1
FROM ghcr.io/linuxserver/baseimage-alpine:3.19 as buildstage

ARG MOD_VERSION

RUN apk add --no-cache curl jq && \
  if [ -z "$MOD_VERSION" ]; then \
    MOD_VERSION=$(curl -s https://api.github.com/repos/rust-lang/rust/releases/latest | jq -r .tag_name); \
  fi && \
  mkdir -p /root-layer/rust-bins && \
  SUPPORTED_PLATFORMS="x86_64-unknown-linux-musl x86_64-unknown-linux-gnu aarch64-unknown-linux-musl aarch64-unknown-linux-gnu" && \
  for PLATFORM in $SUPPORTED_PLATFORMS; do \
    ARCH=${PLATFORM%%-*}; \
    MUSL_OR_GNU=${PLATFORM##*-}; \
    RUST_BINS=/root-layer/rust-bins/rust-${ARCH}-${MUSL_OR_GNU}.tar.gz; \
    RUST_BINS_URL=https://static.rust-lang.org/dist/rust-${MOD_VERSION}-${PLATFORM}.tar.gz; \
    echo "Downloading rust for $PLATFORM";  \
    curl -o $RUST_BINS -sSf $RUST_BINS_URL;  \
  done;

COPY root/ /root-layer/

FROM scratch

LABEL maintainer="totraku"

COPY --from=buildstage /root-layer/ /
