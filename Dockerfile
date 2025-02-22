# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="kenstir"

# copy local files
COPY root/ /
