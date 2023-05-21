# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="wielewout"

# copy local files
COPY root/ /
