# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="alexschomb"

# Add files from buildstage
COPY root/ /
