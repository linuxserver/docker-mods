#!/usr/bin/with-contenv bash

mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases --routines
