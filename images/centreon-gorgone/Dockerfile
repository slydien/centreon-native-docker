# syntax=docker/dockerfile:1.6
#
# centreon-gorgone : Perl/ZMQ task manager
# ----------------------------------------
# VM-install adaptations :
#   * gorgoned.service unit => Perl daemon runs in foreground under tini.
#   * Legacy `centreon centcore-cmd` is gone : Gorgone now talks to
#     centengine through the shared command file (volume `engine-rw`).
#   * SSH and sshpass disabled (modules core::pipeline::*::ssh) — everything
#     stays local in the pod.
#   * RSA keypair generated on first boot (Gorgone requires a pair).

ARG ALMALINUX_VERSION=8
FROM almalinux:${ALMALINUX_VERSION}

ARG CENTREON_VERSION=24.10

LABEL org.opencontainers.image.title="centreon-gorgone" \
      org.opencontainers.image.description="Centreon Gorgone ${CENTREON_VERSION} task manager"

ENV LANG=C.UTF-8 \
    CENTREON_VERSION=${CENTREON_VERSION} \
    GORGONE_CFGDIR=/etc/centreon-gorgone \
    GORGONE_VARDIR=/var/lib/centreon-gorgone \
    GORGONE_LOGDIR=/var/log/centreon-gorgone \
    GORGONE_RUNDIR=/var/run/centreon-gorgone \
    ENGINE_CMDFILE=/var/lib/centreon-engine/rw/centengine.cmd \
    ENGINE_CFGDIR=/etc/centreon-engine

COPY centreon.repo /tmp/centreon.repo.tpl

# hadolint ignore=DL3041
RUN sed "s/__VERSION__/${CENTREON_VERSION}/g" /tmp/centreon.repo.tpl > /etc/yum.repos.d/centreon.repo \
    && rm /tmp/centreon.repo.tpl \
    && dnf install -y --setopt=install_weak_deps=False \
        epel-release glibc-langpack-en dnf-plugins-core \
    && dnf config-manager --set-enabled powertools \
    && dnf install -y --setopt=install_weak_deps=False \
        centreon-gorgone \
        openssl \
        tini \
        gettext \
        procps-ng \
    && dnf clean all && rm -rf /var/cache/dnf \
    && rpm -q centreon-gorgone

RUN mkdir -p \
      "${GORGONE_CFGDIR}/config.d" \
      "${GORGONE_VARDIR}/.keys" \
      "${GORGONE_VARDIR}/history" \
      "${GORGONE_LOGDIR}" \
      "${GORGONE_RUNDIR}" \
    && chown -R 1001:0 \
      "${GORGONE_CFGDIR}" "${GORGONE_VARDIR}" "${GORGONE_LOGDIR}" "${GORGONE_RUNDIR}" \
    && chmod -R g=u \
      "${GORGONE_CFGDIR}" "${GORGONE_VARDIR}" "${GORGONE_LOGDIR}" "${GORGONE_RUNDIR}"

COPY --chown=1001:0 entrypoint.sh  /usr/local/bin/entrypoint.sh
COPY --chown=1001:0 healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chown=1001:0 templates/     /usr/local/share/centreon-gorgone/templates/
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

EXPOSE 5556 8085
USER 1001:0
WORKDIR /var/lib/centreon-gorgone

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=4 \
  CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/gorgoned", "--config=/etc/centreon-gorgone/config.yaml", "--severity=debug"]
