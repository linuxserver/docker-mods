# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="labmonkey"

# copy local files
COPY root/ /
