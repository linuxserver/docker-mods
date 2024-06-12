#!/usr/bin/with-contenv bash

RELOAD_NGINX="false"
NGINX_VALID="true"
DIAG_EXIT="true"

HOST_TLD_ORIG=${AUTO_PROXY_HOST_TLD:=*}
if [[ -v FIRST_RUN ]];then
  echo '**** Auto Proxy - first-run ****'
fi
if [[ -v DOCKER_HOST ]];then
  if [[ -v FIRST_RUN ]];then
    echo '**** Auto Proxy - Detected DOCKER_HOST usage ****'
  fi
  INDEX=1
  IFS=',' read -ra DOCKER_DATA <<< "$DOCKER_HOST"
  for i in "${DOCKER_DATA[@]}"; do
    arrIN=(${i//|/ })
    DOCKER_HOST=${arrIN[0]}
    if [[ -v arrIN[1] ]];then
      DOCKER_HOST_NAME=${arrIN[1]}
    else
      DOCKER_HOST_NAME="host${INDEX}"
    fi

    if [[ -v arrIN[2] ]];then
      AUTO_PROXY_HOST_TLD=${arrIN[2]}
    else
      AUTO_PROXY_HOST_TLD=$HOST_TLD_ORIG
    fi

    # get default upstream ip
    HOST_PARTS=(${DOCKER_HOST//:/ })
    UPSTREAM_HOST="${HOST_PARTS[0]}"

    if [[ -v FIRST_RUN ]];then
      echo "**** Auto Proxy - Generating proxies for => Host: ${DOCKER_HOST} | Name: ${DOCKER_HOST_NAME:-N/A} | Default Upstream IP: ${UPSTREAM_HOST} | Host TLD: ${AUTO_PROXY_HOST_TLD} ****"
    fi
    . /app/auto-proxy.sh
    RES=$?
    if [ $RES == 201 ]; then
      NGINX_VALID="false"
    elif [ $RES == 200 ]; then
      RELOAD_NGINX="true"
    fi

    let INDEX=${INDEX}+1
  done
fi

if [ -S /var/run/docker.sock ]; then
  if [[ -v FIRST_RUN ]];then
    echo "**** Auto Proxy - Detected docker.sock, generating proxies for => Host: Local | Name: Local | Default Upstream IP: N/A | Host TLD: ${AUTO_PROXY_HOST_TLD} ****"
  fi
  DOCKER_HOST_NAME="local"
  unset DOCKER_HOST
  unset UPSTREAM_HOST
  . /app/auto-proxy.sh
  RES=$?
  if [ $RES == 201 ]; then
    NGINX_VALID="false"
  elif [ $RES == 200 ]; then
    RELOAD_NGINX="true"
  fi
fi

if [ "${NGINX_VALID}" == "true" ] && [ "${RELOAD_NGINX}" == "true" ]; then
  echo "**** All changes to nginx config are valid, reloading nginx ****"
  /usr/sbin/nginx -c /config/nginx/nginx.conf -s reload
fi

if [[ -v FIRST_RUN ]];then
  echo '**** Auto Proxy - first-run finished ****'
fi