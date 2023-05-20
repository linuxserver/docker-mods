# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="sanmadjack"

# copy local files
COPY root/ /
