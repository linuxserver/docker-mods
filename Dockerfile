## Buildstage ##
FROM lsiobase/ubuntu:xenial as buildstage

# Stage local files
COPY root/ /root-layer/

## Single layer deployed image ##
FROM scratch

LABEL maintainer="TheCaptain989"

# Copy files from buildstage
COPY --from=buildstage /root-layer/ /
