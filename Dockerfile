# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="dtrunk90"

# copy local files
COPY root/ /
