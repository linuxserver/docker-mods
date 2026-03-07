# beets-httpshell

A [LinuxServer.io Docker Mod](https://github.com/linuxserver/docker-mods) for the [beets](https://github.com/linuxserver/docker-beets) container that adds a lightweight HTTP API to execute `beet` CLI commands remotely.

The mod runs a Python 3 HTTP server (no extra dependencies) that maps URL paths to beet subcommands. Any beet command can be invoked — there is no hardcoded command list.

> **⚠️ Security Warning:** The HTTP API has no authentication or authorization. Any client that can reach the server can execute arbitrary beet commands. It is your responsibility to ensure the API is not exposed to untrusted networks — use firewall rules, Docker network isolation, or a reverse proxy with authentication to restrict access.

## Installation

Add the mod to your beets container using the `DOCKER_MODS` environment variable.

### docker run

```bash
docker run \
  --name=beets \
  -e DOCKER_MODS=ghcr.io/linuxserver/mods:beets-httpshell \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -p 8337:8337 \
  -p 5555:5555 \
  -v /path/to/config:/config \
  -v /path/to/music:/music \
  -v /path/to/downloads:/downloads \
  --restart unless-stopped \
  lscr.io/linuxserver/beets:latest
```

### docker compose

```yaml
---
services:
  beets:
    image: lscr.io/linuxserver/beets:latest
    container_name: beets
    environment:
      DOCKER_MODS: ghcr.io/linuxserver/mods:beets-httpshell
      PUID: 1000
      PGID: 1000
      TZ: Europe/London
      HTTPSHELL_PORT: 5555
    volumes:
      - /path/to/config:/config
      - /path/to/music:/music
      - /path/to/downloads:/downloads
    ports:
      - 8337:8337
      - 5555:5555
    restart: unless-stopped
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `BEET_CMD` | `/lsiopy/bin/beet` | Path to the `beet` binary |
| `BEET_CONFIG` | `/config/config.yaml` | Path to the beets config file |
| `HTTPSHELL_PORT` | `5555` | Port the HTTP server listens on |
| `HTTPSHELL_BLOCKING_TIMEOUT` | `30` | Seconds to wait for the lock in `blocking` mode before the job is queued |

## API Usage

### Execute a command

```
POST /<command>?mode=blocking
Content-Type: application/json

["arg1", "arg2", ...]
```

The URL path is the beet subcommand. The optional `?mode=` query parameter controls execution mode (`blocking`, `async`, or `queued` — defaults to `blocking`). The JSON body is an array of string arguments. An empty body or `[]` means no arguments.

**Response** (200 OK):

```json
{
  "command": "stats",
  "args": [],
  "exit_code": 0,
  "stdout": "Tracks: 1234\nTotal time: 3.2 days\n...",
  "stderr": ""
}
```

### Health check

```
GET /health
```

Returns `200 OK` with server status:

```json
{
  "status": "ok",
  "default_mode": "blocking",
  "queue_size": 0
}
```

### Examples

```bash
# Get library stats (default blocking mode)
curl -X POST http://localhost:5555/stats

# List all tracks by an artist
curl -X POST http://localhost:5555/list \
  -H "Content-Type: application/json" \
  -d '["artist:Radiohead"]'

# Import music asynchronously (returns result when done, runs in parallel with other async requests)
curl -X POST 'http://localhost:5555/import?mode=async' \
  -H "Content-Type: application/json" \
  -d '["/downloads/music", "--quiet", "--incremental"]'

# Queue an import (returns 202 immediately, runs in background)
curl -X POST 'http://localhost:5555/import?mode=queued' \
  -H "Content-Type: application/json" \
  -d '["/downloads/music"]'

# Update the library
curl -X POST http://localhost:5555/update

# Get beets configuration
curl -X POST http://localhost:5555/config

# Remove tracks matching a query (force, delete files)
curl -X POST http://localhost:5555/remove \
  -H "Content-Type: application/json" \
  -d '["artist:test", "-d", "-f"]'

# Move items to a new directory
curl -X POST http://localhost:5555/move \
  -H "Content-Type: application/json" \
  -d '["artist:Radiohead", "-d", "/music/favorites"]'

# Health check
curl http://localhost:5555/health
```

## Execution Modes

The execution mode is controlled per-request via the `?mode=` query parameter. If omitted, defaults to `blocking`.

### `blocking` (default)

Each request waits for a global lock. If the lock is acquired within `HTTPSHELL_BLOCKING_TIMEOUT` seconds, the command runs and the result is returned (200). If the timeout expires, the job is queued and a 202 is returned instead. This ensures commands run one at a time.

```
Request 1 ──▶ [acquires lock, runs command] ──▶ 200 response
Request 2 ──▶ [waits for lock... acquired]  ──▶ 200 response
Request 3 ──▶ [waits for lock... timeout]   ──▶ 202 (queued)
```

### `async`

Each request runs its command immediately in its own thread. Multiple commands execute in parallel. The response is returned when the command finishes.

```
Request 1 ──▶ [runs command] ──▶ 200 response
Request 2 ──▶ [runs command] ──▶ 200 response  (runs in parallel)
```

### `queued`

Every request returns `202 Accepted` immediately. Commands are placed in a FIFO queue and executed one at a time by a background worker. Useful for commands that shouldn't overlap (e.g., `import`).

```
Request 1 ──▶ 202 (queued, position 1)
Request 2 ──▶ 202 (queued, position 2)
                    [worker runs command 1, then command 2]
```

**202 Response:**

```json
{
  "status": "queued",
  "command": "import",
  "args": ["/downloads/album"],
  "queue_size": 1
}
```

## Lidarr Integration

Use beets-httpshell as a Lidarr custom script to automatically import downloads. In Lidarr, go to **Settings → Connect → +** and add a **Custom Script** with the path to the script below.

Create the script at a path accessible to Lidarr (e.g., `/config/scripts/beets-import.sh`):

```bash
#!/usr/bin/env bash

if [ -z "$lidarr_artist_path" ]; then
    echo "Error: lidarr_artist_path environment variable not set"
    echo "Available environment variables:"
    env | grep -i lidarr
    exit 1
fi

curl -X POST --fail-with-body \
    -H "Content-Type: application/json" \
    -d "[\"$lidarr_artist_path\"]" \
    'http://beets:5555/import?mode=queued'

if [ $? -ne 0 ]; then
    echo "Import request failed"
    exit 1
fi
```

> **Note:** The script uses `?mode=queued` so Lidarr gets an immediate 202 response and doesn't block while beets processes the import. Adjust the hostname (`beets`) and port (`5555`) to match your setup.

## Mod Structure

```text
root/
├── usr/local/bin/
│   └── beets-httpshell.py              # HTTP server script
└── etc/s6-overlay/s6-rc.d/
    ├── init-mod-beets-httpshell/       # oneshot init (startup banner, env validation)
    ├── svc-mod-beets-httpshell/        # longrun service (HTTP server)
    ├── init-mods-end/dependencies.d/
    │   └── init-mod-beets-httpshell
    └── user/contents.d/
        ├── init-mod-beets-httpshell
        └── svc-mod-beets-httpshell
```
