#!/usr/bin/env bash
set -euo pipefail
PORT="${BROKER_RRD_PORT:-5670}"
(echo > "/dev/tcp/127.0.0.1/${PORT}") >/dev/null 2>&1 && pgrep -x cbd >/dev/null
