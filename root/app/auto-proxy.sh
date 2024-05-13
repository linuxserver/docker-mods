#!/usr/bin/with-contenv bash

AUTO_GEN=""
SWAG_VARS=(
    swag_address
    swag_port
    swag_proto
    swag_url
    swag_auth
    swag_auth_bypass
    swag_server_custom_directive
    swag_conf
)

# figure out which containers to generate confs for or which confs to remove
if [ ! -f /auto-proxy/enabled_containers ]; then
    docker ps --filter "label=swag=enable" --format "{{.Names}}" > /auto-proxy/enabled_containers
    AUTO_GEN=$(cat /auto-proxy/enabled_containers)
else
    ENABLED_CONTAINERS=$(docker ps --filter "label=swag=enable" --format "{{.Names}}")
    for CONTAINER in ${ENABLED_CONTAINERS}; do
        if [ ! -f "/auto-proxy/${CONTAINER}.conf" ]; then
            echo "**** New container ${CONTAINER} detected, will generate new conf. ****"
            AUTO_GEN="${CONTAINER} ${AUTO_GEN}"
        else
            INSPECTION=$(docker inspect ${CONTAINER})
            for VAR in ${SWAG_VARS[@]}; do
                VAR_VALUE=$(echo ${INSPECTION} | jq -r ".[0].Config.Labels[\"${VAR}\"]")
                if [ "${VAR_VALUE}" == "null" ]; then
                    VAR_VALUE=""
                fi
                if ! grep -F -q "${VAR}=\"${VAR_VALUE}\"" "/auto-proxy/${CONTAINER}.conf"; then
                    AUTO_GEN="${CONTAINER} ${AUTO_GEN}"
                    echo "**** Labels for ${CONTAINER} changed, will generate new conf. ****"
                    break
                fi
            done
        fi
    done
    EXISTING_CONFS=$(cat /auto-proxy/enabled_containers)
    for CONTAINER in $EXISTING_CONFS; do
        if ! grep -q "${CONTAINER}" <<< "${ENABLED_CONTAINERS}"; then
            echo "**** Removing conf for ${CONTAINER} ****"
            rm -rf "/auto-proxy/${CONTAINER}.conf" "$CONF_FILE"
            REMOVED_CONTAINERS="true"
        fi
    done
    echo "${ENABLED_CONTAINERS}" > /auto-proxy/enabled_containers
fi

for CONTAINER in ${AUTO_GEN}; do
    INSPECTION=$(docker inspect ${CONTAINER})
    rm -rf "/auto-proxy/${CONTAINER}.conf"
    for VAR in ${SWAG_VARS[@]}; do
        VAR_VALUE=$(echo ${INSPECTION} | jq -r ".[0].Config.Labels[\"${VAR}\"]")
        if [ "${VAR_VALUE}" == "null" ]; then
            VAR_VALUE=""
        fi
        echo "${VAR}=\"${VAR_VALUE}\"" >> "/auto-proxy/${CONTAINER}.conf"
    done
    . /auto-proxy/${CONTAINER}.conf

    # If the user did not specify an explicit conf file name, we fall back to the container name.
    if [ -z "$swag_conf" ]; then
        swag_conf="$CONTAINER"
    else
        echo "**** Overriding preset conf name as $swag_conf for $CONTAINER ****"
    fi

    CONF_FILE="/etc/nginx/http.d/auto-proxy-${CONTAINER}.subdomain.conf"

    if [ -f "/config/nginx/proxy-confs/${swag_conf}.subdomain.conf.sample" ]; then
        cp "/config/nginx/proxy-confs/${swag_conf}.subdomain.conf.sample" "$CONF_FILE"
        echo "**** Using preset proxy conf for ${CONTAINER} ****"
        if [ -n "${swag_auth_bypass}" ]; then
            echo "**** Swag auth bypass is auto managed via preset confs and cannot be overridden via env vars ****"
        fi
        if [ -n "${swag_address}" ]; then
            sed -i "s|set \$upstream_app .*|set \$upstream_app ${swag_address};|g" "$CONF_FILE"
            echo "**** Overriding address as ${swag_address} for ${CONTAINER} ****"
        fi
        if [ -n "${swag_port}" ]; then
            sed -i "s|set \$upstream_port .*|set \$upstream_port ${swag_port};|g" "$CONF_FILE"
            echo "**** Overriding port as ${swag_port} for ${CONTAINER} ****"
        fi
        if [ -n "${swag_proto}" ]; then
            sed -i "s|set \$upstream_proto .*|set \$upstream_proto ${swag_proto};|g" "$CONF_FILE"
            echo "**** Overriding proto as ${swag_proto} for ${CONTAINER} ****"
        fi
        if [ -n "${swag_url}" ]; then
            SED_swag_url=$(sed -e 's/[&\\|]/\\&/g; s|$|\\|; $s|\\$||' <<<"${swag_url}")
            sed -i "s|server_name .*|server_name ${SED_swag_url};|" "$CONF_FILE"
            echo "**** Overriding url as ${swag_url} for ${CONTAINER} ****"
        fi
        if [ -n "${swag_server_custom_directive}" ]; then
            SED_swag_server_custom_directive=$(sed -e 's/[&\\|]/\\&/g; s|$|\\|; $s|\\$||' <<<"${swag_server_custom_directive}")
            sed -i -e '/include.*ssl.conf;/a\' -e "    ${SED_swag_server_custom_directive}" "$CONF_FILE"
            echo "**** Adding custom directive from the swag_server_custom_directive label for ${CONTAINER} ****"
        fi
        if [ "${swag_auth}" == "authelia" ]; then
            sed -i "s|#include /config/nginx/authelia|include /config/nginx/authelia|g" "$CONF_FILE"
            echo "**** Enabling Authelia for ${CONTAINER} ****"
        elif [ "${swag_auth}" == "authentik" ]; then
            sed -i "s|#include /config/nginx/authentik|include /config/nginx/authentik|g" "$CONF_FILE"
            echo "**** Enabling Authentik for ${CONTAINER} ****"
        elif [ "${swag_auth}" == "http" ]; then
            sed -i "s|#auth_basic|auth_basic|g" "$CONF_FILE"
            echo "**** Enabling basic http auth for ${CONTAINER} ****"
        elif [ "${swag_auth}" == "ldap" ]; then
            # Old (before standard-base)
            sed -i "s|#include /config/nginx/ldap.conf;|include /config/nginx/ldap.conf;|g" "$CONF_FILE"
            sed -i "s|#auth_request /auth;|auth_request /auth;|g" "$CONF_FILE"
            sed -i "s|#error_page 401 =200 /ldaplogin;|error_page 401 =200 /ldaplogin;|g" "$CONF_FILE"
            # New (after standard-base)
            sed -i "s|#include /config/nginx/ldap-server.conf;|include /config/nginx/ldap-server.conf;|g" "$CONF_FILE"
            sed -i "s|#include /config/nginx/ldap-location.conf;|include /config/nginx/ldap-location.conf;|g" "$CONF_FILE"
            echo "**** Enabling basic http auth for ${CONTAINER} ****"
        fi
    else
        echo "**** No preset proxy conf found for ${CONTAINER}, generating from scratch ****"
        cp "/config/nginx/proxy-confs/_template.subdomain.conf.sample" "$CONF_FILE"
        if [ -n "${swag_auth_bypass}" ]; then
            sed -i 's|^}$||' "$CONF_FILE"
            for location in $(echo ${swag_auth_bypass} | tr "," " "); do
                cat <<DUDE >> "$CONF_FILE"

    location ~ ${location} {
        include /config/nginx/proxy.conf;
        include /config/nginx/resolver.conf;
        set \$upstream_app <container_name>;
        set \$upstream_port <port_number>;
        set \$upstream_proto <http or https>;
        proxy_pass \$upstream_proto://\$upstream_app:\$upstream_port;

    }

DUDE
            done
            echo "}" >> "$CONF_FILE"
        fi
        if [ -z "${swag_address}" ]; then
            swag_address="${CONTAINER}"
        fi
        sed -i "s|<container_name>|${swag_address}|g" "$CONF_FILE"
        echo "**** Setting upstream address ${swag_address} for ${CONTAINER} ****"
        if [ -z "${swag_port}" ]; then
            swag_port=$(docker inspect ${CONTAINER} | jq -r '.[0].NetworkSettings.Ports | keys[0]' | sed 's|/.*||')
            if [ "${swag_port}" == "null" ]; then
                echo "**** No exposed ports found for ${CONTAINER}. Setting reverse proxy port to 80. ****"
                swag_port="80"
            fi
        fi
        sed -i "s|set \$upstream_port .*|set \$upstream_port ${swag_port};|g" "$CONF_FILE"
        echo "**** Setting port ${swag_port} for ${CONTAINER} ****"
        if [ -z "${swag_proto}" ]; then
            swag_proto="http"
        fi
        sed -i "s|set \$upstream_proto .*|set \$upstream_proto ${swag_proto};|g" "$CONF_FILE"
        echo "**** Setting proto ${swag_proto} for ${CONTAINER} ****"
        if [ -z "${swag_url}" ]; then
            swag_url="${CONTAINER}.*"
        fi
        SED_swag_url=$(sed -e 's/[&\\|]/\\&/g; s|$|\\|; $s|\\$||' <<<"${swag_url}")
        sed -i "s|server_name .*|server_name ${SED_swag_url};|" "$CONF_FILE"
        echo "**** Setting url ${swag_url} for ${CONTAINER} ****"
        if [ -n "${swag_server_custom_directive}" ]; then
            SED_swag_server_custom_directive=$(sed -e 's/[&\\|]/\\&/g; s|$|\\|; $s|\\$||' <<<"${swag_server_custom_directive}")
            sed -i -e '/include.*ssl.conf;/a\' -e "    ${SED_swag_server_custom_directive}" "$CONF_FILE"
            echo "**** Adding custom directive from the swag_server_custom_directive label for ${CONTAINER} ****"
        fi
        if [ "${swag_auth}" == "authelia" ]; then
            sed -i "s|#include /config/nginx/authelia|include /config/nginx/authelia|g" "$CONF_FILE"
            echo "**** Enabling Authelia for ${CONTAINER} ****"
        elif [ "${swag_auth}" == "authentik" ]; then
            sed -i "s|#include /config/nginx/authentik|include /config/nginx/authentik|g" "$CONF_FILE"
            echo "**** Enabling Authentik for ${CONTAINER} ****"
        elif [ "${swag_auth}" == "http" ]; then
            sed -i "s|#auth_basic|auth_basic|g" "$CONF_FILE"
            echo "**** Enabling basic http auth for ${CONTAINER} ****"
        elif [ "${swag_auth}" == "ldap" ]; then
            # Old (before standard-base)
            sed -i "s|#include /config/nginx/ldap.conf;|include /config/nginx/ldap.conf;|g" "$CONF_FILE"
            sed -i "s|#auth_request /auth;|auth_request /auth;|g" "$CONF_FILE"
            sed -i "s|#error_page 401 =200 /ldaplogin;|error_page 401 =200 /ldaplogin;|g" "$CONF_FILE"
            # New (after standard-base)
            sed -i "s|#include /config/nginx/ldap-server.conf;|include /config/nginx/ldap-server.conf;|g" "$CONF_FILE"
            sed -i "s|#include /config/nginx/ldap-location.conf;|include /config/nginx/ldap-location.conf;|g" "$CONF_FILE"
            echo "**** Enabling basic http auth for ${CONTAINER} ****"
        fi
    fi
done

if ([ -n "${AUTO_GEN}" ] || [ "${REMOVED_CONTAINERS}" == "true" ]) && ps aux | grep [n]ginx: > /dev/null; then
    if /usr/sbin/nginx -c /config/nginx/nginx.conf -t; then
        echo "**** Changes to nginx config are valid, reloading nginx ****"
        /usr/sbin/nginx -c /config/nginx/nginx.conf -s reload
    else
        echo "**** Changes to nginx config are not valid, skipping nginx reload. Please double check the config including the auto-proxy confs. ****"
    fi
fi
