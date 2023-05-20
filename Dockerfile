# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="robomagus"

# copy local files
COPY root/ /
