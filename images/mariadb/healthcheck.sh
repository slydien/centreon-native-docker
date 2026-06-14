#!/usr/bin/env bash
# MariaDB healthcheck : SELECT 1 over the local Unix socket
set -euo pipefail
SOCKET="${MARIADB_RUNDIR:-/var/run/mysqld}/mysqld.sock"
exec mariadb --socket="${SOCKET}" -u root -p"${MARIADB_ROOT_PASSWORD}" \
  -N -e "SELECT 1" >/dev/null
