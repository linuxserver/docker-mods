# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="somewatson"

# copy local files
COPY root/ /
