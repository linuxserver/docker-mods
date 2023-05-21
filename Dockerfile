# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="si458"

# copy local files
COPY root/ /
