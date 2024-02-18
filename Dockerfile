# syntax=docker/dockerfile:1
FROM ghcr.io/linuxserver/baseimage-alpine:3.19 as buildstage

ARG MOD_VERSION

RUN \
  echo "**** Retrieving rust version ****" && \
  if [ -z "$MOD_VERSION" ]; then \
    MOD_VERSION=$(curl -s https://api.github.com/repos/rust-lang/rust/releases/latest | jq -r .tag_name); \
  fi && \
  mkdir -p /root-layer/rust-bins && \
  if [ $(uname -m) = "x86_64" ]; then \
    echo "**** Downloading x86_64 tarball ****" && \
    curl -fo \
      /root-layer/rust-bins/rust.tar.gz -L \
      "https://static.rust-lang.org/dist/rust-${MOD_VERSION}-x86_64-unknown-linux-gnu.tar.gz"; \
  elif [ $(uname -m) = "aarch64" ]; then \
    echo "**** Downloading aarch64 tarball ****" && \
    curl -fo \
      /root-layer/rust-bins/rust.tar.gz -L \
      "https://static.rust-lang.org/dist/rust-${MOD_VERSION}-aarch64-unknown-linux-gnu.tar.gz"; \
  fi

COPY root/ /root-layer/

FROM scratch

LABEL maintainer="totraku"

COPY --from=buildstage /root-layer/ /
