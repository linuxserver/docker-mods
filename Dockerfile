# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="mattx433"

# copy local files
COPY root/ /
