# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="hatchmt"

# copy local files
COPY root/ /
