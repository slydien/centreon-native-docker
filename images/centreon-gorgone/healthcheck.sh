#!/usr/bin/env bash
# Gorgone healthcheck : process alive + HTTP port listening
set -euo pipefail
PORT="${GORGONE_HTTP_PORT:-8085}"
(echo > "/dev/tcp/127.0.0.1/${PORT}") >/dev/null 2>&1 && pgrep -f gorgoned >/dev/null
