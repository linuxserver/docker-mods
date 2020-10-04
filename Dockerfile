FROM lsiobase/nginx:3.12 as buildstage

RUN \
 apk add --no-cache \
    git && \
    mkdir -p /root-layer/geoip2influx && \
    git clone https://github.com/gilbN/geoip2influx.git /root-layer/geoip2influx


COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="GilbN"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /