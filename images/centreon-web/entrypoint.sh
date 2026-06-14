#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# centreon-web entrypoint
#
# Responsibilities :
#   1. Render centreon.conf.php from environment variables
#   2. On first boot : import the Centreon SQL schema (bypass the PHP
#      wizard) and create the admin account
#   3. Run the supervisor (httpd + php-fpm)
# ---------------------------------------------------------------------------
set -euo pipefail

TEMPLATE_DIR=/usr/local/share/centreon-web/templates
log() { printf '[web-entrypoint] %s\n' "$*" >&2; }

# ------- Required env vars ---------------------------------------------------
: "${CENTREON_DB_HOST:?must be set}"
: "${CENTREON_DB_USER:?must be set}"
: "${CENTREON_DB_PASS:?must be set}"
: "${CENTREON_ADMIN_PASS:?must be set}"

export CENTREON_DB_HOST \
       CENTREON_DB_PORT="${CENTREON_DB_PORT:-3306}" \
       CENTREON_DB_USER \
       CENTREON_DB_PASS \
       CENTREON_DB_NAME="${CENTREON_DB_NAME:-centreon}" \
       CENTREON_STORAGE_DB_NAME="${CENTREON_STORAGE_DB_NAME:-centreon_storage}" \
       CENTREON_ADMIN_USER="${CENTREON_ADMIN_USER:-admin}" \
       CENTREON_ADMIN_PASS \
       CENTREON_INSTANCE_NAME="${CENTREON_INSTANCE_NAME:-Central}" \
       GORGONE_HOST="${GORGONE_HOST:-127.0.0.1}" \
       GORGONE_HTTP_PORT="${GORGONE_HTTP_PORT:-8085}"

# ------- Render centreon.conf.php --------------------------------------------
# Use envsubst with an explicit allow-list so the PHP `$conf_centreon`
# variables aren't accidentally erased.
CONF_PHP=/etc/centreon/centreon.conf.php
if [[ ! -s "${CONF_PHP}" ]] || [[ "${CENTREON_REGENERATE:-0}" == "1" ]]; then
  log "rendering ${CONF_PHP}"
  envsubst '${CENTREON_DB_HOST} ${CENTREON_DB_PORT} ${CENTREON_DB_USER} ${CENTREON_DB_PASS} ${CENTREON_DB_NAME} ${CENTREON_STORAGE_DB_NAME} ${GORGONE_HOST} ${GORGONE_HTTP_PORT}' \
    < "${TEMPLATE_DIR}/centreon.conf.php.tpl" > "${CONF_PHP}"
  chmod 0640 "${CONF_PHP}"
fi

# ------- Wait for MariaDB ----------------------------------------------------
log "waiting for MariaDB ${CENTREON_DB_HOST}:${CENTREON_DB_PORT}"
for _ in $(seq 1 90); do
  (echo > "/dev/tcp/${CENTREON_DB_HOST}/${CENTREON_DB_PORT}") >/dev/null 2>&1 && break
  sleep 2
done

# ------- First boot : import the schema + create admin -----------------------
mysql_args=(--host="${CENTREON_DB_HOST}" --port="${CENTREON_DB_PORT}"
            --user="${CENTREON_DB_USER}" --password="${CENTREON_DB_PASS}")

table_count=$(mysql "${mysql_args[@]}" -N -e \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${CENTREON_DB_NAME}'" \
  2>/dev/null || echo 0)

if [[ "${table_count}" -lt 10 ]]; then
  log "centreon DB looks empty (${table_count} tables) — importing schema"
  install_dir=/usr/share/centreon/www/install

  # Strict ordering for the Centreon SQL files (FK constraints :
  # timeperiod/commands before contact/host ; insertBaseConf second to
  # last ; installBroker last).
  apply() { local db="$1" file="$2"; log "  -> ${db}: $(basename "${file}")"
            mysql "${mysql_args[@]}" "${db}" < "${file}"; }

  apply "${CENTREON_DB_NAME}"         "${install_dir}/createTables.sql"
  apply "${CENTREON_STORAGE_DB_NAME}" "${install_dir}/createTablesCentstorage.sql"
  apply "${CENTREON_DB_NAME}"         "${install_dir}/insertTimeperiods.sql"
  apply "${CENTREON_DB_NAME}"         "${install_dir}/insertCommands.sql"
  apply "${CENTREON_DB_NAME}"         "${install_dir}/insertMacros.sql"
  apply "${CENTREON_DB_NAME}"         "${install_dir}/insertBaseConf.sql"
  apply "${CENTREON_DB_NAME}"         "${install_dir}/insertACL.sql"
  apply "${CENTREON_DB_NAME}"         "${install_dir}/insertTopology.sql"
  # /!\ installBroker.sql must target centreon_storage (tables hosts,
  # services, downtimes, instances, schemaversion are used by cbd's
  # 'unified_sql' output and by /api/latest/monitoring/resources).
  apply "${CENTREON_STORAGE_DB_NAME}" "${install_dir}/installBroker.sql"

  # Substitute the @centreon_xxx@ / @rrdtool_dir@ / @plugin_dir@
  # placeholders in `centreon.options` (the PHP install wizard normally
  # does this).
  log "substituting @placeholder@ values in centreon.options"
  mysql "${mysql_args[@]}" "${CENTREON_DB_NAME}" <<-SQL
    UPDATE options SET value = REPLACE(value, '@centreon_dir@',         '/usr/share/centreon')          WHERE value LIKE '%@centreon_dir@%';
    UPDATE options SET value = REPLACE(value, '@centreon_log@',         '/var/log/centreon')            WHERE value LIKE '%@centreon_log@%';
    UPDATE options SET value = REPLACE(value, '@centreon_etc@',         '/etc/centreon')                WHERE value LIKE '%@centreon_etc@%';
    UPDATE options SET value = REPLACE(value, '@centreon_var_lib@',     '/var/lib/centreon')            WHERE value LIKE '%@centreon_var_lib@%';
    UPDATE options SET value = REPLACE(value, '@centreon_cacheengine@', '/var/cache/centreon/config/engine') WHERE value LIKE '%@centreon_cacheengine@%';
    UPDATE options SET value = REPLACE(value, '@centreon_cachebroker@', '/var/cache/centreon/config/broker') WHERE value LIKE '%@centreon_cachebroker@%';
    UPDATE options SET value = REPLACE(value, '@centreon_engine_etc@',  '/etc/centreon-engine')         WHERE value LIKE '%@centreon_engine_etc@%';
    UPDATE options SET value = REPLACE(value, '@centreon_broker_etc@',  '/etc/centreon-broker')         WHERE value LIKE '%@centreon_broker_etc@%';
    UPDATE options SET value = REPLACE(value, '@plugin_dir@',           '/usr/lib/nagios/plugins')      WHERE value LIKE '%@plugin_dir@%';
    UPDATE options SET value = REPLACE(value, '@rrdtool_dir@',          '/usr/bin/rrdtool')             WHERE value LIKE '%@rrdtool_dir@%';
    UPDATE options SET value = REPLACE(value, '@mail@',                 '/usr/sbin/sendmail')           WHERE value LIKE '%@mail@%';
    UPDATE options SET value = REPLACE(value, '@mailer@',               '/usr/sbin/sendmail')           WHERE value LIKE '%@mailer@%';
    UPDATE options SET value = REPLACE(value, '@php_bin@',              '/usr/bin/php')                 WHERE value LIKE '%@php_bin@%';
SQL
  mkdir -p /var/log/centreon /var/cache/centreon/config/engine /var/cache/centreon/config/broker 2>/dev/null || true

  # Admin account : Centreon 24.x uses the `contact_password` table (bcrypt).
  # insertBaseConf drops a '@admin_password@' placeholder there that the
  # PHP wizard substitutes ; we replace it ourselves through PHP.
  log "setting admin password (bcrypt via PHP)"
  bcrypt=$(php -r "echo password_hash('${CENTREON_ADMIN_PASS}', PASSWORD_BCRYPT);")
  mysql "${mysql_args[@]}" "${CENTREON_DB_NAME}" <<-SQL
    UPDATE contact
       SET contact_email = 'admin@localhost'
     WHERE contact_alias = '${CENTREON_ADMIN_USER}';
    UPDATE contact_password
       SET password = '${bcrypt}'
     WHERE contact_id = (SELECT contact_id FROM contact
                          WHERE contact_alias = '${CENTREON_ADMIN_USER}');
SQL

  # Set the Centreon version in `informations` (sentinel key so the UI
  # doesn't fire the install wizard).
  # - MUST be the exact version of the installed RPM (e.g. 24.10.27), else
  #   the wizard triggers incremental upgrades 24.10.0 -> 24.10.X which
  #   fail since the schema delivered by createTables.sql is already on
  #   the target version.
  rpm_version=$(rpm -q --qf '%{VERSION}' centreon 2>/dev/null \
                 || echo "${CENTREON_VERSION:-24.10}")
  log "marking install as completed (DB version=${rpm_version})"
  mysql "${mysql_args[@]}" "${CENTREON_DB_NAME}" <<-SQL
    DELETE FROM informations WHERE \`key\` IN
      ('version', 'isCloudPlatform');
    INSERT INTO informations (\`key\`, \`value\`) VALUES
      ('version', '${rpm_version}'),
      ('isCloudPlatform', 'no');
SQL

  # Create the "Central" poller (id 1) — the install wizard normally does
  # this automatically. Without this row, the REST API
  # /configuration/hosts refuses creates with "monitoringServerId 1 does
  # not exist".
  # engine_*_command / broker_reload_command must match the regex
  # VALID_COMMAND_*_REGEX :
  #   /^(service <unit> <action>|systemctl <action> <unit>)$/
  # In a container, /usr/local/bin/service is our wrapper that maps
  # "service centengine reload" => kill -HUP centengine.
  log "registering Central poller"
  mysql "${mysql_args[@]}" "${CENTREON_DB_NAME}" <<-SQL
    INSERT IGNORE INTO nagios_server
      (id, name, localhost, ns_ip_address, ns_activate, is_default,
       gorgone_communication_type, gorgone_port, ssh_port,
       nagios_bin, nagiostats_bin,
       engine_start_command, engine_stop_command,
       engine_restart_command, engine_reload_command,
       broker_reload_command,
       centreonbroker_cfg_path, centreonbroker_module_path,
       centreonbroker_logs_path, centreonconnector_path)
    VALUES
      (1, '${CENTREON_INSTANCE_NAME}', '1', '127.0.0.1', '1', 1,
       1, 5556, 22,
       '/usr/sbin/centengine', '/usr/sbin/centenginestats',
       'service centengine start',  'service centengine stop',
       'service centengine restart','service centengine reload',
       'service cbd reload',
       '/etc/centreon-broker', '/usr/share/centreon/lib/centreon-broker',
       '/var/log/centreon-broker', '/usr/lib64/centreon-connector');
    INSERT IGNORE INTO cfg_nagios
      (nagios_id, nagios_name, nagios_server_id, nagios_activate,
       log_file, cfg_dir, status_file, command_file)
    VALUES
      (1, '${CENTREON_INSTANCE_NAME}', 1, '1',
       '/var/log/centreon-engine/centengine.log',
       '/etc/centreon-engine',
       '/var/lib/centreon-engine/status.dat',
       '/var/lib/centreon-engine/rw/centengine.cmd');
    -- cfg_nagios_logger : without this row, generateFiles.php crashes
    -- (engine.class.php:394 array_merge with a FALSE).
    -- The default column values are fine.
    INSERT IGNORE INTO cfg_nagios_logger (cfg_nagios_id) VALUES (1);
SQL

  # Tables missing from installBroker.sql as shipped by centreon-web :
  # - data_bin : historical perfdata values (unified_sql writer)
  # - logs    : event log archive (centengine via cbmod)
  # Sources : broker/sql/mysql_v2/{data_bin,logs}.sql in centreon-collect@24.10.x.
  log "creating broker storage tables (data_bin, logs)"
  mysql "${mysql_args[@]}" "${CENTREON_STORAGE_DB_NAME}" <<-'SQL'
    CREATE TABLE IF NOT EXISTS data_bin (
      id_metric int NOT NULL,
      ctime     int NOT NULL,
      status    enum('0','1','2','3','4') NOT NULL default '3',
      value     float default NULL,
      FOREIGN KEY (id_metric) REFERENCES metrics (metric_id) ON DELETE CASCADE,
      INDEX (id_metric)
    ) ENGINE=InnoDB;

    CREATE TABLE IF NOT EXISTS logs (
      ctime                int default NULL,
      host_id              int default NULL,
      host_name            varchar(255) default NULL,
      instance_name        varchar(255) NOT NULL,
      issue_id             int default NULL,
      msg_type             tinyint default NULL,
      notification_cmd     varchar(255) default NULL,
      notification_contact varchar(255) default NULL,
      output               text default NULL,
      retry                int default NULL,
      service_description  varchar(255) default NULL,
      service_id           int default NULL,
      status               tinyint default NULL,
      type                 smallint default NULL,
      INDEX (host_name), INDEX (service_description), INDEX (status),
      INDEX (instance_name), INDEX (ctime),
      INDEX (host_id, service_id, msg_type, status, ctime),
      INDEX (host_id, msg_type, status, ctime),
      INDEX (host_id, service_id, msg_type, ctime, status),
      INDEX (host_id, msg_type, ctime, status),
      FOREIGN KEY (host_id) REFERENCES hosts (host_id) ON DELETE SET NULL
    ) ENGINE=InnoDB;
SQL
fi

# ------- Disable the install wizard at every boot ----------------------------
# Without this, /centreon/install/upgrade.php remains reachable and triggers
# a chain of incremental upgrades (driven by $_SESSION['step']) which fail
# because the schema is already at the target version.
if [[ -d /usr/share/centreon/www/install ]]; then
  log "disabling install wizard (mv install -> install.disabled)"
  mv /usr/share/centreon/www/install \
     /usr/share/centreon/www/install.disabled 2>/dev/null || true
fi

# PHP sessions : purge stale sessions from a previous boot (e.g. a user
# stuck on a now-obsolete upgrade wizard step).
rm -f /var/lib/php/session/sess_* 2>/dev/null || true

# ------- Render central-module.json in /etc/centreon-broker (shared volume)
# Always regenerate : must contain our poller_id, bbdo_version, etc.
mkdir -p /etc/centreon-broker
log "writing cbmod (central-module.json) for engine"
envsubst < "${TEMPLATE_DIR}/central-module.json.tpl" \
  > /etc/centreon-broker/central-module.json

# ------- Start the supervisor (httpd + php-fpm) ------------------------------
exec "$@"
