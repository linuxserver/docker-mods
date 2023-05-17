# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="MiguelNdeCarvalho"

# copy local files
COPY root/ /
