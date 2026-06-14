# syntax=docker/dockerfile:1.6
#
# centreon-web : Apache httpd + PHP-FPM + Centreon UI
# ---------------------------------------------------
# VM-install adaptations :
#   * httpd.service and php-fpm.service units => both processes are
#     supervised by supervisor.sh (a tiny bash script that launches them
#     with `wait -n` and propagates SIGTERM to both).
#   * /var/log/* redirected to stdout for kubelet/Loki collection.
#   * On first boot, if the install wizard hasn't run, the entrypoint
#     applies the Centreon SQL schema in headless mode using the SQL
#     scripts shipped by the RPM
#     (/usr/share/centreon/www/install/createTables.sql etc.).

ARG ALMALINUX_VERSION=8
FROM almalinux:${ALMALINUX_VERSION}

ARG CENTREON_VERSION=24.10

LABEL org.opencontainers.image.title="centreon-web" \
      org.opencontainers.image.description="Centreon Web UI ${CENTREON_VERSION}"

ENV LANG=C.UTF-8 \
    CENTREON_VERSION=${CENTREON_VERSION} \
    CENTREON_ETC=/etc/centreon \
    CENTREON_VARDIR=/var/lib/centreon \
    CENTREON_LOGDIR=/var/log/centreon \
    HTTPD_RUNDIR=/var/run/httpd \
    PHP_FPM_RUNDIR=/var/run/php-fpm \
    HTTPD_LOGDIR=/var/log/httpd \
    HTTPD_PORT=8080

# CENTREON_VERSION accepts a major.minor branch or a full X.Y.Z release ;
# the major.minor part is what ends up in the Centreon repo URL.
COPY centreon.repo /tmp/centreon.repo.tpl

# hadolint ignore=DL3041
RUN CENTREON_BRANCH=$(echo "${CENTREON_VERSION}" | cut -d. -f1-2) \
    && sed "s/__VERSION__/${CENTREON_BRANCH}/g" /tmp/centreon.repo.tpl > /etc/yum.repos.d/centreon.repo \
    && rm /tmp/centreon.repo.tpl \
    && dnf install -y --setopt=install_weak_deps=False \
        epel-release glibc-langpack-en dnf-plugins-core \
    && dnf config-manager --set-enabled powertools \
    # Centreon 24.10 requires PHP 8.2 (present in EL8 AppStream) ; we
    # stay on distro modules instead of Remi to keep sources stable.
    && dnf module reset php -y \
    && dnf module enable php:8.2 -y \
    && dnf install -y --setopt=install_weak_deps=False \
        centreon \
        httpd \
        mod_ssl \
        php-fpm \
        php-mysqlnd \
        php-gd \
        php-intl \
        php-ldap \
        php-mbstring \
        php-soap \
        php-xml \
        php-pecl-apcu \
        mariadb \
        tini \
        gettext \
        procps-ng \
        curl \
    && dnf clean all && rm -rf /var/cache/dnf

# Permissions : group 0 + g=u everywhere (arbitrary OpenShift UID)
RUN mkdir -p \
      "${CENTREON_ETC}" "${CENTREON_VARDIR}" "${CENTREON_LOGDIR}" \
      "${HTTPD_RUNDIR}" "${PHP_FPM_RUNDIR}" "${HTTPD_LOGDIR}" \
      /var/lib/centreon/metrics /var/lib/centreon/status \
      /usr/share/centreon/www/img/media \
      /var/cache/centreon/symfony /var/lib/php/session /var/lib/php/wsdlcache \
    && chown -R 1001:0 \
      "${CENTREON_ETC}" "${CENTREON_VARDIR}" "${CENTREON_LOGDIR}" \
      "${HTTPD_RUNDIR}" "${PHP_FPM_RUNDIR}" "${HTTPD_LOGDIR}" \
      /usr/share/centreon /etc/httpd /etc/php-fpm.d /var/log/php-fpm \
      /var/cache/centreon /var/lib/php \
    && chmod -R g=u \
      "${CENTREON_ETC}" "${CENTREON_VARDIR}" "${CENTREON_LOGDIR}" \
      "${HTTPD_RUNDIR}" "${PHP_FPM_RUNDIR}" "${HTTPD_LOGDIR}" \
      /usr/share/centreon /etc/httpd /etc/php-fpm.d /var/log/php-fpm \
      /var/cache/centreon /var/lib/php

# httpd : non-privileged port 8080 (OpenShift-compatible).
# SSL : removed (TLS terminated by the OpenShift Route).
# Centreon VirtualHost : flip *:80 to *:8080.
# php-fpm centreon pool : the RPM ships a Unix-socket config but the
# httpd vhost /etc/httpd/conf.d/10-centreon.conf hits fcgi://127.0.0.1:9042.
# We align the pool on TCP 9042 + drop the user/group directives that
# require root (arbitrary OpenShift UID).
RUN sed -i \
      -e 's|^Listen 80|Listen 8080|' \
      -e 's|^User apache|#User apache|' \
      -e 's|^Group apache|#Group apache|' \
      /etc/httpd/conf/httpd.conf \
    && rm -f /etc/httpd/conf.d/ssl.conf \
    && sed -i 's|<VirtualHost \*:80>|<VirtualHost *:8080>|' \
      /etc/httpd/conf.d/10-centreon.conf \
    && sed -i \
      -e 's|^listen = .*|listen = 127.0.0.1:9042|' \
      -e 's|^listen.allowed_clients|;listen.allowed_clients|' \
      -e 's|^user = .*|;user = apache|' \
      -e 's|^group = .*|;group = apache|' \
      /etc/php-fpm.d/centreon.conf \
    # Loosen /var/run/php-fpm for arbitrary UID
    && chmod -R g=u /var/run/php-fpm /var/lib/php /var/log/php-fpm

# Redirect logs to stdout/stderr for kubelet
RUN ln -sf /dev/stdout /var/log/httpd/access_log \
    && ln -sf /dev/stderr /var/log/httpd/error_log

COPY --chown=1001:0 entrypoint.sh   /usr/local/bin/entrypoint.sh
COPY --chown=1001:0 supervisor.sh   /usr/local/bin/supervisor.sh
COPY --chown=1001:0 healthcheck.sh  /usr/local/bin/healthcheck.sh
COPY --chown=1001:0 templates/      /usr/local/share/centreon-web/templates/
RUN chmod 0755 /usr/local/bin/entrypoint.sh \
               /usr/local/bin/supervisor.sh \
               /usr/local/bin/healthcheck.sh

# ----- `sudo` + `service` wrappers -----
# To generate/reload the config, Centreon Web runs :
#   shell_exec("sudo -n -- service centengine reload")
# But in a container :
#   - no sudo (no root, no PAM)
#   - no systemd / no SysV `service`
# With spec.shareProcessNamespace: true at the Pod level, the web container
# can see the centengine PID and signal it with SIGHUP (= native reload).
# We install two shell wrappers under /usr/local/bin (which precedes
# /usr/sbin in PATH) :
#   - sudo : passthrough (ignores -n --)
#   - service <unit> <action> : routes to SIGHUP/SIGTERM as appropriate.
RUN cat > /usr/local/bin/sudo <<'WRAPPER' && chmod 0755 /usr/local/bin/sudo
#!/usr/bin/env bash
# Passthrough wrapper : `sudo -n -- cmd args` => exec `cmd args` directly.
while [[ "${1:-}" == -* ]] || [[ "${1:-}" == "--" ]]; do shift; done
exec "$@"
WRAPPER

RUN cat > /usr/local/bin/service <<'WRAPPER' && chmod 0755 /usr/local/bin/service
#!/usr/bin/env bash
# Minimal `service <unit> <action>` wrapper — systemd substitute.
# The pod's PID namespace is shared (shareProcessNamespace: true), so
# pgrep -x centengine returns the PID running in the engine container.
set -euo pipefail
unit="${1:-}"
action="${2:-}"
log() { printf '[service-wrapper] %s\n' "$*" >&2; }

case "${unit}:${action}" in
  centengine:reload|centengine:restart)
    pid=$(pgrep -x centengine || true)
    [[ -z "${pid}" ]] && { log "centengine not running"; exit 1; }
    log "SIGHUP centengine (PID ${pid}) for ${action}"
    kill -HUP "${pid}" || exit 1
    ;;
  centengine:start|centengine:stop)
    # start/stop : owned by K8s lifecycle, not by us
    log "${action} centengine — no-op (managed by K8s)"
    ;;
  cbd:reload|cbd:restart)
    # cbd auto-reloads its JSON config when the file changes ; we still
    # signal every cbd to force it.
    for pid in $(pgrep -x cbd || true); do
      log "SIGHUP cbd (PID ${pid})"
      kill -HUP "${pid}" || true
    done
    ;;
  *:*)
    log "unknown unit/action: ${unit} ${action}"
    exit 1
    ;;
  *)
    log "usage: service <unit> <action>"
    exit 1
    ;;
esac
WRAPPER

# ----- PHP patch : MonitoringServerConfigurationRepositoryApi -----
# Centreon Web's internal HttpClient (Symfony) builds the export URL with
# SERVER_NAME but NOT SERVER_PORT => default HTTP 80 while we listen on 8080.
# Patch `initUri()` at build time to include the port.
RUN PHP_FILE=/usr/share/centreon/src/Centreon/Infrastructure/MonitoringServer/Repository/MonitoringServerConfigurationRepositoryApi.php \
    && OLD="\$this->serverUri = \$serverScheme . '://' . \$_SERVER['SERVER_NAME'] . '/' . \$prefixUri;" \
    && NEW="\$port = \$_SERVER['SERVER_PORT'] ?? '80'; \$this->serverUri = \$serverScheme . '://' . \$_SERVER['SERVER_NAME'] . ':' . \$port . '/' . \$prefixUri;" \
    && php -r "\$f='$PHP_FILE'; \$c=file_get_contents(\$f); \$c=str_replace(\$argv[1], \$argv[2], \$c); file_put_contents(\$f, \$c);" "$OLD" "$NEW" \
    && grep -q "SERVER_PORT" "$PHP_FILE" && echo "PHP patch OK"

EXPOSE 8080
USER 1001:0
WORKDIR /var/lib/centreon

HEALTHCHECK --interval=20s --timeout=8s --start-period=90s --retries=5 \
  CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/supervisor.sh"]
