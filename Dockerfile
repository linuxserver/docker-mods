FROM lsiobase/alpine:3.11 as buildstage

# copy local files
COPY root/ /root-layer/

# runtime stage
FROM scratch

LABEL maintainer="alexschomb"

# Add files from buildstage
COPY --from=buildstage /root-layer/ /

# volumes
VOLUME /translations