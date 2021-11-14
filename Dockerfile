FROM scratch

LABEL maintainer="alexschomb"

# copy local files
COPY root/ /

# install translations
RUN chmod +x /install-translations.sh
CMD /install-translations.sh
