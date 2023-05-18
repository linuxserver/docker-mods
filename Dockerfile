FROM ghcr.io/linuxserver/baseimage-alpine:3.15 as grab-stage

RUN \
 apk add --no-cache --upgrade \
    curl \
    tar && \
 mkdir -p /root/defaults/nginx/proxy-confs && \
 curl -o \
    /tmp/proxy.tar.gz -L \
    "https://github.com/linuxserver/reverse-proxy-confs/tarball/master" && \
 tar xf \
    /tmp/proxy.tar.gz -C \
    /root/defaults/nginx/proxy-confs \
    --strip-components=1 \
    --exclude=linux*/.gitattributes \
    --exclude=linux*/.github \
    --exclude=linux*/.gitignore \
    --exclude=linux*/LICENSE
# copy local files
COPY root/ root/

ADD https://raw.githubusercontent.com/linuxserver/docker-swag/master/root/defaults/nginx/proxy.conf.sample /root/defaults/nginx/proxy.conf.sample

ADD https://raw.githubusercontent.com/linuxserver/docker-baseimage-alpine-nginx/master/root/defaults/nginx/dhparams.pem /root/defaults/nginx/dhparams.pem

FROM scratch

LABEL maintainer="Roxedus"

# copy proxy-confs
COPY --from=grab-stage root/ /
