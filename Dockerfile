# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="tylernguyen"

# copy local files
COPY root/ /
