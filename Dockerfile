# syntax=docker/dockerfile:1

FROM scratch as buildstage

ADD https://raw.githubusercontent.com/gilbN/geoip2influx/master/run.py /root-layer/geoip2influx/run.py
ADD https://raw.githubusercontent.com/gilbN/geoip2influx/master/geoip2influx/__init__.py /root-layer/geoip2influx/geoip2influx/__init__.py
ADD https://raw.githubusercontent.com/GilbN/geoip2influx/master/geoip2influx/constants.py /root-layer/geoip2influx/geoip2influx/constants.py
ADD https://raw.githubusercontent.com/gilbN/geoip2influx/master/geoip2influx/influx_base.py /root-layer/geoip2influx/geoip2influx/influx_base.py
ADD https://raw.githubusercontent.com/gilbN/geoip2influx/master/geoip2influx/influx.py /root-layer/geoip2influx/geoip2influx/influx.py
ADD https://raw.githubusercontent.com/gilbN/geoip2influx/master/geoip2influx/influxv2.py /root-layer/geoip2influx/geoip2influx/influxv2.py
ADD https://raw.githubusercontent.com/gilbN/geoip2influx/master/geoip2influx/logger.py /root-layer/geoip2influx/geoip2influx/logger.py
ADD https://raw.githubusercontent.com/gilbN/geoip2influx/master/geoip2influx/logparser.py /root-layer/geoip2influx/geoip2influx/logparser.py
COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="GilbN"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /
