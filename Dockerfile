# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="aptalca"

# copy local files
COPY root/ /
