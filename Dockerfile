# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="ksurl"

# copy local files
COPY root/ /
