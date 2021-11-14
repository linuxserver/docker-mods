FROM scratch

LABEL maintainer="alexschomb"

# copy local files
COPY root/ /

# install languages
RUN chmod +x /install-translations.sh
CMD /install-translations.sh