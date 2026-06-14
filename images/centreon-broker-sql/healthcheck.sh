#!/usr/bin/env bash
# broker-sql healthcheck : cbd is listening on BBDO_PORT and the process is alive
set -euo pipefail
PORT="${BROKER_BBDO_PORT:-5669}"
(echo > "/dev/tcp/127.0.0.1/${PORT}") >/dev/null 2>&1 && pgrep -x cbd >/dev/null
