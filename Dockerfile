# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="quietsy"

# copy local files
COPY root/ /
