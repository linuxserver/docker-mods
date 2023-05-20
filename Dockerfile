# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="Spunkie"

# copy local files
COPY root/ /
