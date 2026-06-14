#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# reload.sh : substitute for `systemctl reload centengine`
#
# Three strategies, tried in order :
#   1. If we can read the PID file => SIGHUP (centengine reloads its config)
#   2. Otherwise, write RESTART_PROGRAM to the command file (internal
#      centengine command)
#   3. Otherwise, exit 1 (the caller — Gorgone — will decide what to do)
# ---------------------------------------------------------------------------
set -euo pipefail

PIDFILE="${CENTREON_ENGINE_RUNDIR:-/var/run/centreon-engine}/centengine.pid"
CMDFILE="${CENTREON_ENGINE_VARDIR:-/var/lib/centreon-engine}/rw/centengine.cmd"

if [[ -s "${PIDFILE}" ]]; then
  pid=$(cat "${PIDFILE}")
  if kill -0 "${pid}" 2>/dev/null; then
    echo "[engine-reload] sending SIGHUP to PID ${pid}" >&2
    kill -HUP "${pid}"
    exit 0
  fi
fi

if [[ -p "${CMDFILE}" ]] || [[ -e "${CMDFILE}" ]]; then
  ts=$(date +%s)
  echo "[engine-reload] writing RESTART_PROGRAM to ${CMDFILE}" >&2
  printf '[%d] RESTART_PROGRAM\n' "${ts}" > "${CMDFILE}"
  exit 0
fi

echo "[engine-reload] no PID file and no command file — cannot reload" >&2
exit 1
