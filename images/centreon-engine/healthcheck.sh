#!/usr/bin/env bash
# centengine healthcheck : process is alive + command file accessible
# Note 24.x : the FIFO is `centengine.cmd_read` (with the `_read` suffix).
set -euo pipefail
PIDFILE="${CENTREON_ENGINE_RUNDIR:-/var/run/centreon-engine}/centengine.pid"
RWDIR="${CENTREON_ENGINE_VARDIR:-/var/lib/centreon-engine}/rw"

if [[ -s "${PIDFILE}" ]] && kill -0 "$(cat "${PIDFILE}")" 2>/dev/null; then
  # Command file present (cmd or cmd_read depending on version)
  [[ -e "${RWDIR}/centengine.cmd" || -e "${RWDIR}/centengine.cmd_read" ]] && exit 0
  exit 1
fi

# Fallback : pgrep
pgrep -x centengine >/dev/null 2>&1
