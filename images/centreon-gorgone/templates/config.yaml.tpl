# ============================================================================
# Gorgone — config fragment dropped into /etc/centreon-gorgone/config.d/
# The RPM ships /etc/centreon-gorgone/config.yaml which aggregates every
# .yaml under config.d ; we follow that include layout rather than replace
# the root file.
#
# Container specifics :
#   - No SSH : everything is local in the pod
#   - command_file points to the shared volume /var/lib/centreon-engine/rw/
#   - HTTP API on 0.0.0.0:8085, no auth (defense via NetworkPolicy, the
#     external Route is only on centreon-web)
# ============================================================================

centreon:
  database:
    db_configuration:
      dsn: "mysql:host=${CENTREON_DB_HOST};port=${CENTREON_DB_PORT};dbname=${CENTREON_DB_NAME}"
      username: "${CENTREON_DB_USER}"
      password: "${CENTREON_DB_PASS}"
    db_realtime:
      dsn: "mysql:host=${CENTREON_DB_HOST};port=${CENTREON_DB_PORT};dbname=${CENTREON_STORAGE_DB_NAME}"
      username: "${CENTREON_DB_USER}"
      password: "${CENTREON_DB_PASS}"

gorgone:
  gorgonecore:
    id: ${GORGONE_ID}
    external_com_type: tcp
    external_com_path: "*:${GORGONE_ZMQ_PORT}"
    privkey: "${GORGONE_VARDIR}/.keys/rsakey.priv.pem"
    pubkey:  "${GORGONE_VARDIR}/.keys/rsakey.pub.pem"
    authorized_clients:
      - key: ""
    log_level: info
    timeout: 50

  modules:
    - name: httpserver
      package: "gorgone::modules::core::httpserver::hooks"
      enable: true
      address: "0.0.0.0"
      port: "${GORGONE_HTTP_PORT}"
      ssl: false
      auth:
        enabled: false
      allowed_hosts:
        enabled: false

    - name: cron
      package: "gorgone::modules::core::cron::hooks"
      enable: true

    - name: engine
      package: "gorgone::modules::centreon::engine::hooks"
      enable: true
      command_file: "${ENGINE_CMDFILE}"

    - name: legacycmd
      package: "gorgone::modules::centreon::legacycmd::hooks"
      enable: true
      cmd_file: "${ENGINE_CMDFILE}"
      cache_dir: "${GORGONE_VARDIR}/legacycmd/"
      cache_dir_trap: "${GORGONE_VARDIR}/legacycmd/trap/"

    - name: nodes
      package: "gorgone::modules::centreon::nodes::hooks"
      enable: true

    - name: proxy
      package: "gorgone::modules::core::proxy::hooks"
      enable: true
