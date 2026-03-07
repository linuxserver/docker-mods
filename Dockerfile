# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="dyptan-io"

# copy local files
COPY root/ /