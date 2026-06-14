#!/usr/bin/env bash
# centreon-broker-sql entrypoint
set -euo pipefail

CFG="${BROKER_CFGDIR}/central-broker.json"
TEMPLATE="/usr/local/share/centreon-broker/templates/central-broker.json.tpl"

log() { printf '[broker-sql-entrypoint] %s\n' "$*" >&2; }

# ------- Required env vars ---------------------------------------------------
: "${BROKER_DB_HOST:?BROKER_DB_HOST must be set}"
: "${BROKER_DB_USER:?BROKER_DB_USER must be set}"
: "${BROKER_DB_PASS:?BROKER_DB_PASS must be set}"

export BROKER_DB_HOST \
       BROKER_DB_PORT="${BROKER_DB_PORT:-3306}" \
       BROKER_DB_USER \
       BROKER_DB_PASS \
       BROKER_DB_NAME="${BROKER_DB_NAME:-centreon}" \
       BROKER_STORAGE_DB_NAME="${BROKER_STORAGE_DB_NAME:-centreon_storage}" \
       BROKER_BBDO_PORT="${BROKER_BBDO_PORT:-5669}" \
       BROKER_RRD_HOST="${BROKER_RRD_HOST:-127.0.0.1}" \
       BROKER_RRD_PORT="${BROKER_RRD_PORT:-5670}" \
       BROKER_LOGDIR \
       BROKER_VARDIR

# ------- Render the config ---------------------------------------------------
# The RPM installs a default central-broker.json that doesn't match our pod
# topology — we always regenerate so our endpoints (broker-rrd, local DB)
# stay in sync with the environment variables.
log "rendering ${CFG} from template"
envsubst < "${TEMPLATE}" > "${CFG}"

# ------- Wait for MariaDB ----------------------------------------------------
log "waiting for MariaDB ${BROKER_DB_HOST}:${BROKER_DB_PORT}"
for _ in $(seq 1 60); do
  (echo > "/dev/tcp/${BROKER_DB_HOST}/${BROKER_DB_PORT}") >/dev/null 2>&1 && break
  sleep 2
done

trap 'log "SIGTERM"; kill -TERM "${child_pid:-1}" 2>/dev/null || true' TERM
log "starting cbd (sql instance): $*"
"$@" &
child_pid=$!
wait "${child_pid}"
