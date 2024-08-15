#!/command/with-contenv bash
# shellcheck shell=bash

# Custom script to install Striptracks Mod meant for Radarr or Sonarr Docker containers
# WARNING: Minimal error handling!

# Pre-set LSIO Docker Mod variables
DOCKER_MODS=linuxserver/mods:radarr-striptracks
#DOCKER_MODS_DEBUG=true
export DOCKER_MODS
export DOCKER_MODS_DEBUG
[ "$DOCKER_MODS_DEBUG" = "true" ] && echo "[mod-install] DOCKER_MODS: $DOCKER_MODS" && echo "[mod-install] DOCKER_MODS_DEBUG: $DOCKER_MODS_DEBUG"
echo "[mod-install] installing $DOCKER_MODS mod"

# Steal the current docker-mods version from the source
MODS_VERSION=$(curl -s --fail-with-body "https://raw.githubusercontent.com/linuxserver/docker-baseimage-alpine/master/Dockerfile" | sed -nr 's/^ARG MODS_VERSION="?([^"]+)"?/\1/p')
[ "$DOCKER_MODS_DEBUG" = "true" ] && echo "[mod-install] MODS_VERSION: $MODS_VERSION"

# Download and execute the main docker-mods script to install the mod
# Very well thought out code, this.  Why reinvent?
curl -s --fail-with-body -o /docker-mods "https://raw.githubusercontent.com/linuxserver/docker-mods/mod-scripts/docker-mods.${MODS_VERSION}"
ret=$?
[ $ret -ne 0 ] && echo "[mod-install] unable to download docker-mods: Exit code: $ret. Exiting." && exit 1

chmod +x /docker-mods

. /docker-mods
[ $ret -ne 0 ] && echo "[mod-install] docker-mods installation error: $ret. Exiting." && exit 1

# Get script version from installed mod
VERSION=$(sed -nr 's/^export striptracks_ver="?([^"]+)"?/\1/p' /usr/local/bin/striptracks.sh)
[ "$DOCKER_MODS_DEBUG" = "true" ] && echo "[mod-install] striptracks.sh version: $VERSION"

# Remaining setup that is normally done with s6-overlay init scripts, but that rely on a lot of Docker Mods dependencies
cat <<EOF
----------------
>>> Striptracks Mod by TheCaptain989 <<<
Repos:
  Dev/test: https://github.com/TheCaptain989/radarr-striptracks
  Prod: https://github.com/linuxserver/docker-mods/tree/radarr-striptracks

Version: ${VERSION}
----------------
EOF

# Determine if setup is needed
if [ ! -f /usr/bin/mkvmerge ]; then
  echo "[mod-install] Running first time setup."

  if [ -f /usr/bin/apt ]; then
    # Ubuntu
    echo "[mod-install] Installing MKVToolNix using apt-get"
    apt-get update && \
        apt-get -y install mkvtoolnix && \
        rm -rf /var/lib/apt/lists/*
  elif [ -f /sbin/apk ]; then
    # Alpine
    echo "[mod-install] Installing MKVToolNix using apk"
    apk upgrade --no-cache && \
        apk add --no-cache mkvtoolnix && \
        rm -rf /var/lib/apt/lists/*
  else
    # Unknown
    echo "[mod-install] Unknown package manager.  Attempting to install MKVToolNix using apt-get"
    apt-get update && \
        apt-get -y install mkvtoolnix && \
        rm -rf /var/lib/apt/lists/*
  fi
fi

# Check ownership and attributes on each script file
[ -z "$PUID" ] && owner_user="root" || owner_user="$PUID"
[ -z "$PGID" ] && owner_group="root" || owner_group="$PGID"
for file in /usr/local/bin/striptracks*.sh
do
  # Change ownership
  if [ "$(stat -c '%G' "$file")" != "$owner_group" ]; then
    echo "[mod-install] Changing ownership on $file script to $owner_user:$owner_group."
    chown "$owner_user":"$owner_group" "$file"
  fi

  # Make executable
  if [ ! -x "$file" ]; then
    echo "[mod-install] Making $file script executable."
    chmod +x "$file"
  fi
done
