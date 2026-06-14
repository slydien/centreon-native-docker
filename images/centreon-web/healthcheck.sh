#!/usr/bin/env bash
# centreon-web healthcheck : Apache responds + Symfony bootstraps cleanly
# (installation/status is a public endpoint that exercises both PHP and DB).
set -euo pipefail
PORT="${HTTPD_PORT:-8080}"
exec curl --fail --silent --max-time 5 \
  "http://127.0.0.1:${PORT}/centreon/api/latest/platform/installation/status" \
  >/dev/null
