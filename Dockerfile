# syntax=docker/dockerfile:1

FROM lscr.io/linuxserver/baseimage-alpine:3.19 as buildstage

RUN \
  apk add --no-cache \
    git && \
  git clone https://github.com/ohmyzsh/ohmyzsh.git /root-layer/.oh-my-zsh

COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="MiguelNdeCarvalho"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
