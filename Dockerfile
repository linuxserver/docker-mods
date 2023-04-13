# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="username"

# copy local files
COPY root/ /
