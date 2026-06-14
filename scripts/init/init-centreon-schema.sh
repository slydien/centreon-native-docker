#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Init script used as a pod initContainer to copy the Centreon SQL schema
# files from the centreon-web image into the MariaDB initdb volume.
#
# Mounted as an initContainer of the pod :
#   initContainers:
#     - name: copy-schemas
#       image: centreon/centreon-web:24.10
#       command: [/init-centreon-schema.sh]
#       volumeMounts:
#         - { name: mariadb-initdb, mountPath: /target }
# ---------------------------------------------------------------------------
set -euo pipefail
SRC=/usr/share/centreon/www/install
DEST=${1:-/target}
mkdir -p "${DEST}"
for f in createTables.sql createTablesCentstorage.sql insertBaseConf.sql; do
  if [[ -f "${SRC}/${f}" ]]; then
    cp -v "${SRC}/${f}" "${DEST}/${f}"
  fi
done
echo "Schemas copied to ${DEST}"
