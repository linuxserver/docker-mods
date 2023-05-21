# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="MateoPeri"

# copy local files
COPY root/ /
