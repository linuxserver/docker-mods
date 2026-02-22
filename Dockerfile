# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="Stark"

# copy local files
COPY root/ /
