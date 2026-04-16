# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="Koalab99"

# copy local files
COPY root/ /
