# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="phyesix"

# copy local files
COPY root/ /
