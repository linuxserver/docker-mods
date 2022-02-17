FROM ghcr.io/linuxserver/baseimage-alpine:3.15 as buildstage

ARG GO_VERSION

RUN \
 apk add --no-cache \
    curl \
    grep && \
 if [ -z ${GO_VERSION+x} ]; then \
    GO_VERSION=$(curl -sLX GET https://go.dev/dl/ | grep -o '<span.*>.*linux-amd64.*</span>' | grep -oP '(?<=go).*(?=.linux)'); \
 fi && \
 mkdir -p /root-layer/golang && \
 curl -o \
    /root-layer/golang/golang_x86_64.tar.gz -L \
    https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
 curl -o \
    /root-layer/golang/golang_armv7l.tar.gz -L \
    https://go.dev/dl/go${GO_VERSION}.linux-armv6l.tar.gz && \
 curl -o \
    /root-layer/golang/golang_aarch64.tar.gz -L \
    https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="n-i-x"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
