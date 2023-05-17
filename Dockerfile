# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="fabricionaweb"

# copy local files
COPY root/ /
