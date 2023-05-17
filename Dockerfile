# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="PascalMinder"

# copy local files
COPY root/ /
