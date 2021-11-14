#!/bin/bash -e

if [ ! -z "${TRANSLATIONS}" ]; then
  OLDIFS=$IFS
  IFS=','
  for translation in ${TRANSLATIONS}; do
    IFS=$OLDIFS
    echo "**** install translation: ${translation} ****"
    curl -s -o "/tmp/${translation}.zip" -L "https://www.projectsend.org/translations/get.php?lang=${translation}"
    unzip -o "/tmp/${translation}.zip" -d /app/projectsend;
  done
  echo "**** cleanup ****"
  rm -rf /tmp/*
fi

while :; do :; done & kill -STOP $! && wait $!