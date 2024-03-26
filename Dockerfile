# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="melonarc"

# copy local files
COPY root/ /
