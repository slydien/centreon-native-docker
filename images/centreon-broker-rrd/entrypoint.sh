#!/usr/bin/env bash
set -euo pipefail
CFG="${BROKER_CFGDIR}/central-rrd.json"
TEMPLATE="/usr/local/share/centreon-broker/templates/central-rrd.json.tpl"
log() { printf '[broker-rrd-entrypoint] %s\n' "$*" >&2; }

export BROKER_RRD_PORT="${BROKER_RRD_PORT:-5670}" \
       RRD_METRICS_DIR RRD_STATUS_DIR \
       BROKER_LOGDIR BROKER_VARDIR

# The RPM ships a default config that shadows our template ; always
# regenerate (the shared broker-config volume is the single source of truth).
log "rendering ${CFG} from template"
envsubst < "${TEMPLATE}" > "${CFG}"

# Make sure the RRD directories exist (PVC empty on first boot)
mkdir -p "${RRD_METRICS_DIR}" "${RRD_STATUS_DIR}"

trap 'log "SIGTERM"; kill -TERM "${child_pid:-1}" 2>/dev/null || true' TERM
log "starting cbd (rrd instance): $*"
"$@" &
child_pid=$!
wait "${child_pid}"
