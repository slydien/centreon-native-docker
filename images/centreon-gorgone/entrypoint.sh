#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# centreon-gorgone entrypoint
# ---------------------------------------------------------------------------
set -euo pipefail

# The Gorgone RPM ships /etc/centreon-gorgone/config.yaml which includes
# config.d/*.yaml. We drop our config in config.d/ rather than overwrite
# the package's include sentinel file.
CFG="${GORGONE_CFGDIR}/config.d/40-centreon.yaml"
TEMPLATE="/usr/local/share/centreon-gorgone/templates/config.yaml.tpl"
KEYDIR="${GORGONE_VARDIR}/.keys"

log() { printf '[gorgone-entrypoint] %s\n' "$*" >&2; }

: "${CENTREON_DB_HOST:?must be set}"
: "${CENTREON_DB_USER:?must be set}"
: "${CENTREON_DB_PASS:?must be set}"

export CENTREON_DB_HOST \
       CENTREON_DB_PORT="${CENTREON_DB_PORT:-3306}" \
       CENTREON_DB_USER \
       CENTREON_DB_PASS \
       CENTREON_DB_NAME="${CENTREON_DB_NAME:-centreon}" \
       CENTREON_STORAGE_DB_NAME="${CENTREON_STORAGE_DB_NAME:-centreon_storage}" \
       GORGONE_HTTP_PORT="${GORGONE_HTTP_PORT:-8085}" \
       GORGONE_ZMQ_PORT="${GORGONE_ZMQ_PORT:-5556}" \
       GORGONE_ID="${GORGONE_ID:-1}" \
       ENGINE_CMDFILE ENGINE_CFGDIR GORGONE_VARDIR GORGONE_LOGDIR

# ------- RSA key generation (first boot) -------------------------------------
if [[ ! -s "${KEYDIR}/rsakey.priv.pem" ]]; then
  log "generating RSA key pair in ${KEYDIR}"
  mkdir -p "${KEYDIR}"
  openssl genrsa -out "${KEYDIR}/rsakey.priv.pem" 4096
  openssl rsa -in "${KEYDIR}/rsakey.priv.pem" -pubout -out "${KEYDIR}/rsakey.pub.pem"
  chmod 0600 "${KEYDIR}/rsakey.priv.pem"
fi

# ------- Render the config ---------------------------------------------------
mkdir -p "$(dirname "${CFG}")"
if [[ ! -s "${CFG}" ]] || [[ "${GORGONE_REGENERATE:-0}" == "1" ]]; then
  log "rendering ${CFG} from template"
  envsubst < "${TEMPLATE}" > "${CFG}"
fi

# ------- Make sure the shared command file path is reachable -----------------
# /var/lib/centreon-engine/rw is a shared (emptyDir) volume ; centengine
# creates the FIFO at boot, here we just guarantee the path exists.
mkdir -p "$(dirname "${ENGINE_CMDFILE}")"

# ------- ZeroMQ IPC ----------------------------------------------------------
# Gorgone uses /tmp/gorgone/ for inter-module IPC sockets. The directory
# MUST exist BEFORE the fork or child processes die silently.
mkdir -p /tmp/gorgone
chmod 0775 /tmp/gorgone

# ------- Wait for MariaDB and the engine to be up ----------------------------
log "waiting for MariaDB ${CENTREON_DB_HOST}:${CENTREON_DB_PORT}"
for _ in $(seq 1 60); do
  (echo > "/dev/tcp/${CENTREON_DB_HOST}/${CENTREON_DB_PORT}") >/dev/null 2>&1 && break
  sleep 2
done

trap 'log "SIGTERM"; kill -TERM "${child_pid:-1}" 2>/dev/null || true' TERM
log "starting gorgoned: $*"
"$@" &
child_pid=$!
wait "${child_pid}"
