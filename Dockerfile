# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.20 AS buildstage

ARG MOD_VERSION

RUN \
  mkdir -p /root-layer && \
  if [[ -z "${MOD_VERSION}" ]]; then \
    MOD_VERSION=$(curl -sX GET "https://api.github.com/repos/crowdsecurity/cs-nginx-bouncer/releases/latest" \
    | jq -r '.tag_name'); \
  fi && \
  if [[ -z ${MOD_VERSION+x} ]]; then \
    echo "**** Could not fetch current bouncer version from Github ****" \
    exit 1; \
  fi && \
  curl -sLo \
    /root-layer/crowdsec-nginx-bouncer.tgz -L \
    "https://github.com/crowdsecurity/cs-nginx-bouncer/releases/download/${MOD_VERSION}/crowdsec-nginx-bouncer.tgz" && \
  if ! tar -tzf /root-layer/crowdsec-nginx-bouncer.tgz >/dev/null 2>&1; then \
    echo "**** Invalid tarball, could not download crowdsec bouncer ****" \
    exit 1; \
  fi

COPY root/ /root-layer/

FROM scratch

LABEL maintainer="thespad"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
