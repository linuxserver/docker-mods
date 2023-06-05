# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="josevh"

# copy local files
COPY root/ /
