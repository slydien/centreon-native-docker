# syntax=docker/dockerfile:1.6
#
# centreon-broker-rrd : `cbd` instance dedicated to writing RRD files
# ------------------------------------------------------------------
# Adaptations :
#   * No systemd unit cbd-rrd.service => cbd launched directly by tini.
#   * /var/lib/centreon/{metrics,status} must be a PVC shared with
#     centreon-web so the UI can read the RRD files to render graphs.

ARG ALMALINUX_VERSION=8
FROM almalinux:${ALMALINUX_VERSION}

ARG CENTREON_VERSION=24.10

LABEL org.opencontainers.image.title="centreon-broker-rrd" \
      org.opencontainers.image.description="Centreon Broker ${CENTREON_VERSION} — RRD output instance"

ENV LANG=C.UTF-8 \
    CENTREON_VERSION=${CENTREON_VERSION} \
    BROKER_CFGDIR=/etc/centreon-broker \
    BROKER_VARDIR=/var/lib/centreon-broker \
    BROKER_LOGDIR=/var/log/centreon-broker \
    BROKER_RUNDIR=/var/run/centreon-broker \
    RRD_METRICS_DIR=/var/lib/centreon/metrics \
    RRD_STATUS_DIR=/var/lib/centreon/status \
    BROKER_INSTANCE=rrd

COPY centreon.repo /tmp/centreon.repo.tpl

# hadolint ignore=DL3041
RUN sed "s/__VERSION__/${CENTREON_VERSION}/g" /tmp/centreon.repo.tpl > /etc/yum.repos.d/centreon.repo \
    && rm /tmp/centreon.repo.tpl \
    && dnf install -y --setopt=install_weak_deps=False \
        epel-release glibc-langpack-en dnf-plugins-core \
    && dnf config-manager --set-enabled powertools \
    && dnf install -y --setopt=install_weak_deps=False \
        centreon-broker \
        centreon-broker-core \
        centreon-broker-cbd \
        rrdtool \
        tini \
        gettext \
        procps-ng \
    && dnf clean all && rm -rf /var/cache/dnf

RUN mkdir -p \
      "${BROKER_CFGDIR}" "${BROKER_VARDIR}" "${BROKER_LOGDIR}" "${BROKER_RUNDIR}" \
      "${RRD_METRICS_DIR}" "${RRD_STATUS_DIR}" \
    && chown -R 1001:0 \
      "${BROKER_CFGDIR}" "${BROKER_VARDIR}" "${BROKER_LOGDIR}" "${BROKER_RUNDIR}" \
      "${RRD_METRICS_DIR}" "${RRD_STATUS_DIR}" \
    && chmod -R g=u \
      "${BROKER_CFGDIR}" "${BROKER_VARDIR}" "${BROKER_LOGDIR}" "${BROKER_RUNDIR}" \
      "${RRD_METRICS_DIR}" "${RRD_STATUS_DIR}"

COPY --chown=1001:0 entrypoint.sh  /usr/local/bin/entrypoint.sh
COPY --chown=1001:0 healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chown=1001:0 templates/     /usr/local/share/centreon-broker/templates/
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

EXPOSE 5670
USER 1001:0
WORKDIR /var/lib/centreon-broker

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=4 \
  CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/cbd", "/etc/centreon-broker/central-rrd.json"]
