# syntax=docker/dockerfile:1.6
#
# centreon-engine : monitoring scheduler (centengine)
# ---------------------------------------------------
# Replacements for the VM-with-systemd install :
#   * `centengine.service` unit  => binary launched directly by tini.
#   * `systemctl reload centengine` => reload.sh signals PID 1 with SIGHUP
#     (centengine reloads its config on SIGHUP).
#   * Permissions : USER 1001:0, group 0 recursive on /var/lib/centreon-engine
#     and /etc/centreon-engine for arbitrary-UID OpenShift compatibility.
#   * The command file FIFO (/var/lib/centreon-engine/rw/centengine.cmd_read)
#     is created by centengine itself at boot ; the directory must be a
#     SHARED volume with centreon-gorgone (emptyDir inside the pod).

ARG ALMALINUX_VERSION=8
FROM almalinux:${ALMALINUX_VERSION}

ARG CENTREON_VERSION=24.10

LABEL org.opencontainers.image.title="centreon-engine" \
      org.opencontainers.image.description="Centreon Engine ${CENTREON_VERSION} (centengine)" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV LANG=C.UTF-8 \
    CENTREON_VERSION=${CENTREON_VERSION} \
    CENTREON_ENGINE_CFGDIR=/etc/centreon-engine \
    CENTREON_ENGINE_VARDIR=/var/lib/centreon-engine \
    CENTREON_ENGINE_LOGDIR=/var/log/centreon-engine \
    CENTREON_ENGINE_RUNDIR=/var/run/centreon-engine

# Centreon repo definition (no centreon-release RPM exists at this path —
# we drop the .repo file directly). CENTREON_VERSION can be either a
# major.minor branch ("24.10") or a full X.Y.Z release ("24.10.27") — only
# the branch ends up in the repo URL.
COPY centreon.repo /tmp/centreon.repo.tpl

# hadolint ignore=DL3041,DL3033
RUN CENTREON_BRANCH=$(echo "${CENTREON_VERSION}" | cut -d. -f1-2) \
    && sed "s/__VERSION__/${CENTREON_BRANCH}/g" /tmp/centreon.repo.tpl > /etc/yum.repos.d/centreon.repo \
    && rm /tmp/centreon.repo.tpl \
    && dnf install -y --setopt=install_weak_deps=False \
        epel-release glibc-langpack-en dnf-plugins-core \
    && dnf config-manager --set-enabled powertools \
    && dnf install -y --setopt=install_weak_deps=False \
        centreon-engine \
        centreon-engine-daemon \
        nagios-plugins-all \
        tini \
        gettext \
        procps-ng \
        bind-utils \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# broker_module_directory=/usr/lib64/centreon-engine auto-loads EVERY .so in
# the directory ; for each X.so the loader tries to read X.cfg as argument.
# libopentelemetry.so ships no .cfg → loader passes "" → fatal error
# "Fail to read file ''" that also breaks cbmod loading. We drop a minimal
# OTel gRPC config (schema defined in
# engine/modules/opentelemetry/src/grpc_config.cc upstream). Port 4317 is
# the standard OTLP-gRPC port. To actually use OTel later, point this to a
# real telegraf / centreon-agent.
RUN printf '%s\n' \
      '{' \
      '  "otel_server": {' \
      '    "host": "0.0.0.0",' \
      '    "port": 4317' \
      '  },' \
      '  "max_length_grpc_log": 0' \
      '}' > /usr/lib64/centreon-engine/libopentelemetry.cfg

# Pre-create the directories (pod-shared volumes are mounted on top later)
RUN mkdir -p \
      "${CENTREON_ENGINE_CFGDIR}" \
      "${CENTREON_ENGINE_VARDIR}/rw" \
      "${CENTREON_ENGINE_LOGDIR}" \
      "${CENTREON_ENGINE_RUNDIR}" \
    && chown -R 1001:0 \
      "${CENTREON_ENGINE_CFGDIR}" \
      "${CENTREON_ENGINE_VARDIR}" \
      "${CENTREON_ENGINE_LOGDIR}" \
      "${CENTREON_ENGINE_RUNDIR}" \
    && chmod -R g=u \
      "${CENTREON_ENGINE_CFGDIR}" \
      "${CENTREON_ENGINE_VARDIR}" \
      "${CENTREON_ENGINE_LOGDIR}" \
      "${CENTREON_ENGINE_RUNDIR}"

COPY --chown=1001:0 entrypoint.sh    /usr/local/bin/entrypoint.sh
COPY --chown=1001:0 healthcheck.sh   /usr/local/bin/healthcheck.sh
COPY --chown=1001:0 reload.sh        /usr/local/bin/reload.sh
COPY --chown=1001:0 templates/       /usr/local/share/centreon-engine/templates/
RUN chmod 0755 /usr/local/bin/entrypoint.sh \
               /usr/local/bin/healthcheck.sh \
               /usr/local/bin/reload.sh

USER 1001:0
WORKDIR /var/lib/centreon-engine

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=4 \
  CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/centengine", "/etc/centreon-engine/centengine.cfg"]
