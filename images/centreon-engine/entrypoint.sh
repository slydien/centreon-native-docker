#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# centreon-engine entrypoint
#
# Responsibilities :
#   1. Make sure the shared directories (engine-config, engine-rw) exist
#      and have the right permissions
#   2. Drop a minimal centengine.cfg if the volume is empty (first boot,
#      before Gorgone has pushed its config)
#   3. Render the cbmod config (central-module.json) — the broker-config
#      volume is shared, but engine boots before web, so we own this file
#   4. Export PID 1 to a file that reload.sh can read
#   5. Run centengine in the foreground
# ---------------------------------------------------------------------------
set -euo pipefail

CFG="${CENTREON_ENGINE_CFGDIR}/centengine.cfg"
RUN="${CENTREON_ENGINE_RUNDIR}/centengine.pid"
TEMPLATE_DIR="/usr/local/share/centreon-engine/templates"

log() { printf '[engine-entrypoint] %s\n' "$*" >&2; }

# ------- Permissions on the shared volumes (mounted by the pod) --------------
# engine-rw is shared with gorgone : we make sure both UIDs (1001 in each
# image) can write to it. fsGroup=0 + g=u is enough in practice.
for d in "${CENTREON_ENGINE_VARDIR}/rw" "${CENTREON_ENGINE_CFGDIR}" "${CENTREON_ENGINE_LOGDIR}"; do
  mkdir -p "${d}"
  chmod g+rwxs "${d}" 2>/dev/null || true
done

# ------- Bootstrap config -----------------------------------------------------
# If /etc/centreon-engine is empty, write a minimal centengine.cfg. Gorgone
# will overwrite it as soon as the UI triggers an export.
if [[ ! -s "${CFG}" ]]; then
  log "no ${CFG} found — writing bootstrap config from template"
  export CENTREON_ENGINE_CFGDIR CENTREON_ENGINE_VARDIR CENTREON_ENGINE_LOGDIR
  envsubst < "${TEMPLATE_DIR}/centengine.cfg.tpl" > "${CFG}"

  # Empty object files so centengine doesn't crash for lack of hosts
  : > "${CENTREON_ENGINE_CFGDIR}/hosts.cfg"
  : > "${CENTREON_ENGINE_CFGDIR}/services.cfg"
  : > "${CENTREON_ENGINE_CFGDIR}/contacts.cfg"
  : > "${CENTREON_ENGINE_CFGDIR}/commands.cfg"
  : > "${CENTREON_ENGINE_CFGDIR}/timeperiods.cfg"
  : > "${CENTREON_ENGINE_CFGDIR}/resource.cfg"
fi

# ------- cbmod config : central-module.json ----------------------------------
# The broker-config volume (mounted at /etc/centreon-broker) is shared with
# broker-sql, broker-rrd AND centengine (via cbmod). We render the cbmod
# config HERE rather than depend on centreon-web (timing : engine can boot
# before web).
mkdir -p /etc/centreon-broker
log "writing central-module.json for cbmod"
export CENTREON_INSTANCE_NAME="${CENTREON_INSTANCE_NAME:-Central}" \
       BROKER_SQL_HOST="${BROKER_SQL_HOST:-127.0.0.1}" \
       BROKER_BBDO_PORT="${BROKER_BBDO_PORT:-5669}"
envsubst < "${TEMPLATE_DIR}/central-module.json.tpl" \
  > /etc/centreon-broker/central-module.json

# ------- Wait until broker-sql is listening (BBDO output) --------------------
BROKER_HOST="${BROKER_SQL_HOST:-127.0.0.1}"
BROKER_PORT="${BROKER_BBDO_PORT:-5669}"
log "waiting for broker ${BROKER_HOST}:${BROKER_PORT}"
for _ in $(seq 1 60); do
  (echo > "/dev/tcp/${BROKER_HOST}/${BROKER_PORT}") >/dev/null 2>&1 && break
  sleep 2
done

# ------- Publish our PID for reload.sh (substitute for `systemctl reload`) ---
echo $$ > "${RUN}" || log "WARN: cannot write ${RUN}"

# ------- Signal handling : SIGTERM => clean shutdown -------------------------
trap 'log "received SIGTERM, forwarding to centengine"; kill -TERM "${child_pid:-1}" 2>/dev/null || true' TERM
trap 'log "received SIGHUP, forwarding to centengine";  kill -HUP  "${child_pid:-1}" 2>/dev/null || true' HUP

log "starting centengine: $*"
"$@" &
child_pid=$!
echo "${child_pid}" > "${RUN}"
wait "${child_pid}"
