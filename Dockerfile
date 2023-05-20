# syntax=docker/dockerfile:1

FROM scratch

LABEL maintainer="JonathanTreffler"

# copy local files
COPY root/ /
