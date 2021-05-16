# Build container
FROM golang:alpine AS buildstage

RUN mkdir /cloudflared
WORKDIR /src

RUN apk --no-cache add git build-base curl jq

ENV GO111MODULE=on \
    CGO_ENABLED=0

RUN curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest \
  | jq -rc ".tag_name" \
  | xargs -I TAG sh -c 'git -c advice.detachedHead=false clone https://github.com/cloudflare/cloudflared --depth=1 --branch TAG .'

RUN GOOS=linux GOARCH=amd64 make cloudflared
RUN mv cloudflared /cloudflared/cloudflared-amd64

RUN GOOS=linux GOARCH=arm64 make cloudflared
RUN mv cloudflared /cloudflared/cloudflared-arm64

RUN GOOS=linux GOARCH=arm make cloudflared
RUN mv cloudflared /cloudflared/cloudflared-armhf

# Runtime container
FROM scratch
WORKDIR /

LABEL maintainer="Spunkie"

# copy cloudflared bins
COPY --from=buildstage /cloudflared /cloudflared
# copy local files
COPY root/ /
