# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="alexschomb"

# copy local files
COPY root/ /
