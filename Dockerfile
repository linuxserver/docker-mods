# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="nemchik"

# copy local files
COPY root/ /
