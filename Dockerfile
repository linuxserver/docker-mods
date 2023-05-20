# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="greinet"

# copy local files
COPY root/ /
