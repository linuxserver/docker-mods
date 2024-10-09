# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="howardt12345"

# copy local files
COPY root/ /
