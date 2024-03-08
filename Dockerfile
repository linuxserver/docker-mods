# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/unrar:version-6.2.12 as unrar

FROM scratch as buildstage

# copy local files
COPY root/ /

COPY --from=unrar /usr/bin/unrar-alpine /unrar6/unrar-alpine
COPY --from=unrar /usr/bin/unrar-ubuntu /unrar6/unrar-ubuntu

FROM scratch

LABEL maintainer="thespad"

COPY --from=buildstage / /
