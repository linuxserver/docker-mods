# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="jared-bloomer"

# copy local files
COPY root/ /
