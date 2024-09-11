# Geoip2Influx - Docker mod for nginx/swag


This mod adds a python script that sends geo location metrics from the nginx access log to InfluxDB

![](.assets/geoip2influx.png)


The mod will parse the access log for IPs and and convert them into geo metrics for InfluxDB. It will also send log metrics if enabled. This mod depends on the [swag-maxmind-mod](https://github.com/linuxserver/docker-mods/tree/swag-maxmind)!

Add `-e DOCKER_MODS=linuxserver/mods:swag-geoip2influx|linuxserver/mods:swag-maxmind`

## Enviroment variables:

These are the **default** values for all envs. 
Add the ones that differ on your system. 

| Environment Variable | Example Value | Description |
| -------------------- | ------------- | ----------- |
| NGINX_LOG_PATH | /config/log/nginx/access.log | Container path for Nginx logfile , defaults to the example. |
| GEO_MEASUREMENT | geoip2influx | InfluxDB measurement name for geohashes. Optional, defaults to the example. |
| LOG_MEASUREMENT | nginx_access_logs | InfluxDB measurement name for nginx logs. Optional, defaults to the example. |
| SEND_NGINX_LOGS | true | Set to `false` to disable nginx logs. Optional, defaults to `true`. |
| GEOIP2INFLUX_LOG_LEVEL | info | Sets the log level in geoip2influx.log. Use `debug` for verbose logging Optional, defaults to info. |
| GEOIP2INFLUX_LOG_PATH | /config/log/geoip2influx/geoip2influx.log | Optional. Defaults to example. |
| GEOIP_DB_PATH | /config/geoip2db/GeoLite2-City.mmdb | Optional. Defaults to example. |
| MAXMINDDB_LICENSE_KEY | xxxxxxx | Add your Maxmind licence key |
| MAXMINDDB_USER_ID | xxxxxxx| Add your Maxmind account id |

**InfluxDB v1.8.x values**

| Environment Variable | Example Value | Description |
| -------------------- | ------------- | ----------- |
| INFLUX_HOST | localhost | Host running InfluxDB. |
| INFLUX_HOST_PORT | 8086 | Optional, defaults to 8086. |
| INFLUX_DATABASE | geoip2influx | Optional, defaults to geoip2influx. |
| INFLUX_USER | root | Optional, defaults to root. |
| INFLUX_PASS | root | Optional, defaults to root. |
| INFLUX_RETENTION | 7d | Sets the retention for the database. Optional, defaults to example.|
| INFLUX_SHARD | 1d | Set the shard for the database. Optional, defaults to example. |

**InfluxDB v2.x values**

| Environment Variable | Example Value | Description |
| -------------------- | ------------- | ----------- |
| USE_INFLUXDB_V2 | true | Required if using InfluxDB2. Defaults to false |
| INFLUXDB_V2_TOKEN | secret-token | Required |
| INFLUXDB_V2_URL | http://localhost:8086 | Optional, defaults to http://localhost:8086 |
| INFLUXDB_V2_ORG | geoip2influx | Optional, defaults to geoip2influx. Will be created if not exists. |
| INFLUXDB_V2_BUCKET | geoip2influx | Optional, defaults to geoip2influx. Will be created if not exists. |
| INFLUXDB_V2_RETENTION | 604800 | Optional, defaults to 604800. 7 days in seconds |
| INFLUXDB_V2_DEBUG | false | Optional, defaults to false. Enables the debug mode for the influxdb-client package. |
| INFLUXDB_V2_BATCHING | true | Optional, defaults to false. Enables batch writing of data. |
| INFLUXDB_V2_BATCH_SIZE | 100 | Optional, defaults to 10. |
| INFLUXDB_V2_FLUSH_INTERVAL | 30000 | Optional, defaults to 15000. How often in milliseconds to write a batch |

### INFLUXDB_V2_TOKEN

If the organization or bucket does not exist, it will try and create them with the token.

> [!NOTE]
> The minimim level of rights needed is write access to the bucket.

### MaxMind Geolite2

Get your licence key here: https://www.maxmind.com/en/geolite2/signup

## InfluxDB 

### InfluxDB v2.x and v1.8x is supported.

#### Note: The Grafana dashboard currently only supports InfluxDB v1.8.x

The InfluxDB database/bucket and retention rules will be created automatically with the name you choose.

```
-e INFLUX_DATABASE=geoip2influx or -e INFLUXDB_V2_BUCKET=geoip2influx
```

***

## Grafana dashboard: 

Use [https://github.com/GilbN/geoip2influx/blob/master/nginx_logs_geo_map.json](https://github.com/GilbN/geoip2influx/blob/master/nginx_logs_geo_map.json)

> [!NOTE]
> Dashboard currently only supports InfluxDB 1.8.x.

***

## Sending Nginx log metrics

1. Setup the [swag-maxmind-mod](https://github.com/linuxserver/docker-mods/tree/swag-maxmind)

2. Add the following to the http block in your `nginx.conf`file:

```nginx
log_format geoip2influx '$remote_addr - $remote_user [$time_local]'
           '"$request" $status $body_bytes_sent'
           '"$http_referer" $host "$http_user_agent"'
           '"$request_time" "$upstream_connect_time"'
           '"$geoip2_data_city_name" "$geoip2_data_country_iso_code"';
 ```
 
 3. Set the access log use the `geoip2influx` log format.
 
 Note: The log_format block must be above the access_log context. 
 ```nginx
 access_log /config/log/nginx/access.log geoip2influx;
 ```

### Multiple log files

If you separate your nginx log files but want this mod to parse all of them you can do the following:

As nginx can have multiple `access log` directives in a block, just add another one in the server block. 

**Example**

```nginx
	access_log /config/log/nginx/technicalramblings/access.log;
	access_log /config/log/nginx/access.log geoip2influx;
```
This will log the same lines to both files.

Then use the `/config/log/nginx/access.log` file in the `NGINX_LOG_PATH` variable. 
