# syntax=docker/dockerfile:1.6
#
# centreon-mariadb : based on the official mariadb:10.5 image
# ----------------------------------------------------------
# Why not AlmaLinux 8 ? The default RHEL 8 module ships MariaDB 10.3, which
# is too old for Centreon 24.10 (requires >= 10.5). We use the official
# image which already provides tini, a sane entrypoint and the modern
# `mariadb-*` binaries.
#
# VM-install adaptations :
#   * Arbitrary OpenShift UID : the upstream `mysql` user (UID 999) is
#     replaced by 1001:0 via a recursive chown + chmod g=u.
#   * /etc/my.cnf.d/ extended with Centreon-specific tunings.
#   * The upstream entrypoint is kept : it correctly handles
#     MARIADB_ROOT_PASSWORD and /docker-entrypoint-initdb.d/ while only
#     exposing port 3306 once init is complete.

FROM mariadb:10.5

LABEL org.opencontainers.image.title="centreon-mariadb" \
      org.opencontainers.image.description="MariaDB 10.5 pre-configured for Centreon" \
      org.opencontainers.image.licenses="Apache-2.0"

# Centreon-specific tunings
RUN printf '%s\n' \
      '[mariadbd]' \
      'innodb_file_per_table=1' \
      'open_files_limit=32000' \
      'key_buffer_size=64M' \
      'sort_buffer_size=32M' \
      'join_buffer_size=4M' \
      'thread_cache_size=64' \
      'read_buffer_size=512K' \
      'read_rnd_buffer_size=256K' \
      'max_allowed_packet=64M' \
      'innodb_buffer_pool_size=512M' \
      'innodb_log_file_size=64M' \
      'innodb_log_buffer_size=8M' \
      'innodb_flush_log_at_trx_commit=2' \
      'innodb_io_capacity=200' \
      'character_set_server=utf8mb4' \
      'collation_server=utf8mb4_unicode_ci' \
      > /etc/mysql/conf.d/centreon.cnf

# Healthcheck script (consumed by K8s readiness/liveness probes)
COPY healthcheck.sh   /usr/local/bin/healthcheck.sh
# Optional init scripts (mounted via an initContainer in the pod)
COPY initdb/          /docker-entrypoint-initdb.d/

RUN chmod 0755 /usr/local/bin/healthcheck.sh /docker-entrypoint-initdb.d/*.sh

# OpenShift permissions : every directory that mariadbd touches must
# belong to group 0 + chmod g=u so an arbitrary UID can still write.
RUN chown -R 1001:0 \
      /var/lib/mysql /var/log/mysql /var/run/mysqld \
      /docker-entrypoint-initdb.d /etc/mysql /etc/mysql/conf.d \
    && chmod -R g=u \
      /var/lib/mysql /var/log/mysql /var/run/mysqld \
      /docker-entrypoint-initdb.d /etc/mysql /etc/mysql/conf.d

EXPOSE 3306
USER 1001:0

HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=5 \
  CMD /usr/local/bin/healthcheck.sh

# We keep the upstream ENTRYPOINT (docker-entrypoint.sh) which :
#   - requires MARIADB_ROOT_PASSWORD or MARIADB_ALLOW_EMPTY_ROOT_PASSWORD
#   - creates MYSQL_DATABASE / MYSQL_USER / MYSQL_PASSWORD
#   - runs /docker-entrypoint-initdb.d/*
# Our initdb/01-*.sh and 02-*.sh scripts create the Centreon users and
# databases on top of that.
