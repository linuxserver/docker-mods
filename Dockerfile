# Build container
FROM golang:alpine AS buildstage

ARG CLOUDFLARED_TAG

RUN mkdir -p /root-layer/cloudflared
WORKDIR /src

RUN apk --no-cache add git build-base curl jq

ENV GO111MODULE=on \
    CGO_ENABLED=0

RUN \
  if [ -z "${CLOUDFLARED_TAG}" ]; then \
    curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest \
      | jq -rc ".tag_name" \
      | xargs -I TAG sh -c 'git -c advice.detachedHead=false clone https://github.com/cloudflare/cloudflared --depth=1 --branch TAG .'; \
  else \
    git -c advice.detachedHead=false clone https://github.com/cloudflare/cloudflared --depth=1 --branch ${CLOUDFLARED_TAG} .; \
  fi

RUN GOOS=linux GOARCH=amd64 make cloudflared
RUN mv cloudflared /root-layer/cloudflared/cloudflared-amd64

RUN GOOS=linux GOARCH=arm64 make cloudflared
RUN mv cloudflared /root-layer/cloudflared/cloudflared-arm64

RUN GOOS=linux GOARCH=arm make cloudflared
RUN mv cloudflared /root-layer/cloudflared/cloudflared-armhf

COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="Spunkie"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
