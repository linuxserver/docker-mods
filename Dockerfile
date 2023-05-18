# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="thespad"

# copy local files
COPY root/ /
