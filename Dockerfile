# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="junkman690"

# copy local files
COPY root/ /
