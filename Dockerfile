# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="driz"

# copy local files
COPY root/ /
