# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="flavio20002"

# copy local files
COPY root/ /
