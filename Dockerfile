# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="alex-phillips"

# copy local files
COPY root/ /
