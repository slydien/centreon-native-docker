#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Creates the Centreon databases and user on first boot.
# Run by the official mariadb entrypoint after mariadbd has started in
# --skip-networking mode ; MARIADB_ROOT_PASSWORD and the other variables
# have already been applied at this point.
# ---------------------------------------------------------------------------
set -euo pipefail

: "${CENTREON_DB_USER:?CENTREON_DB_USER must be set}"
: "${CENTREON_DB_PASS:?CENTREON_DB_PASS must be set}"

CENTREON_DB_NAME="${CENTREON_DB_NAME:-centreon}"
CENTREON_STORAGE_DB_NAME="${CENTREON_STORAGE_DB_NAME:-centreon_storage}"

mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" <<-SQL
  SET @@SESSION.SQL_LOG_BIN = 0;

  CREATE DATABASE IF NOT EXISTS \`${CENTREON_DB_NAME}\`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE DATABASE IF NOT EXISTS \`${CENTREON_STORAGE_DB_NAME}\`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

  CREATE USER IF NOT EXISTS '${CENTREON_DB_USER}'@'%'
    IDENTIFIED BY '${CENTREON_DB_PASS}';
  CREATE USER IF NOT EXISTS '${CENTREON_DB_USER}'@'localhost'
    IDENTIFIED BY '${CENTREON_DB_PASS}';

  GRANT ALL PRIVILEGES ON \`${CENTREON_DB_NAME}\`.*
    TO '${CENTREON_DB_USER}'@'%';
  GRANT ALL PRIVILEGES ON \`${CENTREON_STORAGE_DB_NAME}\`.*
    TO '${CENTREON_DB_USER}'@'%';
  GRANT ALL PRIVILEGES ON \`${CENTREON_DB_NAME}\`.*
    TO '${CENTREON_DB_USER}'@'localhost';
  GRANT ALL PRIVILEGES ON \`${CENTREON_STORAGE_DB_NAME}\`.*
    TO '${CENTREON_DB_USER}'@'localhost';

  FLUSH PRIVILEGES;
SQL

# Session tunings
mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" <<-SQL
  SET GLOBAL max_allowed_packet = 67108864;
  SET GLOBAL net_read_timeout   = 300;
  SET GLOBAL net_write_timeout  = 300;
SQL
