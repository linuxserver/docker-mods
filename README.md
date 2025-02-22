# alpine-quieter-cron - Docker mod for containers derived from docker-baseimage-alpine

This mod adds the ability to control the busybox crond logging level during container start.

In docker arguments, set environment variables
```
DOCKER_MODS=kenstir/mods:alpine-quieter-cron
CRON_LOG_LEVEL=7
```
