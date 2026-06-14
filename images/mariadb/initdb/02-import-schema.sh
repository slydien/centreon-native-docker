#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 02-import-schema.sh
#
# Imports the Centreon SQL schemas shipped with the `centreon-common` RPM.
# That RPM lives on the PHP side, so we expect the .sql files to have been
# copied into /docker-entrypoint-initdb.d/centreon-sql/ by an initContainer
# (which mounts the centreon-web image and copies them into an emptyDir).
#
# If the directory is missing (e.g. local build without the pod), we skip
# the import — the schema will be installed by the centreon-web entrypoint
# on first access.
# ---------------------------------------------------------------------------
set -euo pipefail
SQL_DIR="/docker-entrypoint-initdb.d/centreon-sql"
SOCKET="${MARIADB_RUNDIR:-/var/run/mysqld}/mysqld.sock"

if [[ ! -d "${SQL_DIR}" ]]; then
  echo "[02-import-schema] no ${SQL_DIR} — skipping (web entrypoint will install the schema)"
  exit 0
fi

run_sql() {
  local db="$1" file="$2"
  echo "[02-import-schema] importing ${file} into ${db}"
  mariadb --socket="${SOCKET}" -u root -p"${MARIADB_ROOT_PASSWORD}" "${db}" < "${file}"
}

[[ -f "${SQL_DIR}/centreon.sql"         ]] && run_sql "${CENTREON_DB_NAME:-centreon}"                 "${SQL_DIR}/centreon.sql"
[[ -f "${SQL_DIR}/centreon_storage.sql" ]] && run_sql "${CENTREON_STORAGE_DB_NAME:-centreon_storage}" "${SQL_DIR}/centreon_storage.sql"
