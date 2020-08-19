# cron - Docker mod for any container

This mod adds cron to any container.

In the container docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:cron`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:cron|linuxserver/mods:other-mod`

This mod will ensure you have a `/config/crontabs/root` file where you can add cron jobs to run inside the container.

No cron jobs (aside from what may be included in the base OS) are included by default.

You can test to confirm things are working by adding the following line to `/config/crontabs/root`

```cron
*/5 * * * *    /bin/echo test >> /config/tmp.txt
```

Then restart the container and wait 5 minutes to see that the test completes. Remove the test and restart the container after confirming.
