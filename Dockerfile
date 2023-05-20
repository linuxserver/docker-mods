# syntax=docker/dockerfile:1

FROM scratch
LABEL maintainer="Roxedus"


# copy local files
COPY root/ /
