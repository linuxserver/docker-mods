FROM ghcr.io/linuxserver/baseimage-alpine:3.15 as buildstage

ADD https://raw.githubusercontent.com/gilbN/geoip2influx/master/geoip2influx.py /root-layer/geoip2influx/geoip2influx.py
COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="GilbN"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /