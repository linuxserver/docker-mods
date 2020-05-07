FROM lsiobase/alpine:3.11 as buildstage

ARG GO_VERSION

RUN \
 apk add --no-cache \
    curl \
    grep && \
 if [ -z ${GO_VERSION+x} ]; then \
    GO_VERSION=$(curl -sX GET https://golang.org/dl/ | grep -o '<span.*>.*linux-amd64.*</span>' | grep -oP '(?<=go).*(?=.linux)'); \
 fi && \
 mkdir -p /root-layer/usr/local && \
 curl -o \
    /tmp/golang.tar.gz -L \
    https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && \
 tar xzf /tmp/golang.tar.gz -C \
    /root-layer/usr/local

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="n-i-x"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
