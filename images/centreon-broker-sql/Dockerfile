# syntax=docker/dockerfile:1.6
#
# centreon-broker-sql : `cbd` instance that consumes BBDO and writes to SQL
# ------------------------------------------------------------------------
# VM-install adaptations :
#   * `cbd-sql.service` unit => `cbd` binary launched by tini.
#   * No jinja templating on the web side : we render the JSON via envsubst
#     at boot from environment variables.
#   * Forwards to broker-rrd over TCP 5670 (the "central-broker.json" config
#     contains a TCP output pointing at 127.0.0.1:5670).

ARG ALMALINUX_VERSION=8
FROM almalinux:${ALMALINUX_VERSION}

ARG CENTREON_VERSION=24.10

LABEL org.opencontainers.image.title="centreon-broker-sql" \
      org.opencontainers.image.description="Centreon Broker ${CENTREON_VERSION} — SQL output instance"

ENV LANG=C.UTF-8 \
    CENTREON_VERSION=${CENTREON_VERSION} \
    BROKER_CFGDIR=/etc/centreon-broker \
    BROKER_VARDIR=/var/lib/centreon-broker \
    BROKER_LOGDIR=/var/log/centreon-broker \
    BROKER_RUNDIR=/var/run/centreon-broker \
    BROKER_INSTANCE=sql

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
    && dnf install -y --setopt=install_weak_deps=False \
        centreon-broker \
        centreon-broker-core \
        centreon-broker-cbd \
        centreon-broker-storage \
        tini \
        gettext \
        procps-ng \
    && dnf clean all && rm -rf /var/cache/dnf

RUN mkdir -p "${BROKER_CFGDIR}" "${BROKER_VARDIR}" "${BROKER_LOGDIR}" "${BROKER_RUNDIR}" \
    && chown -R 1001:0 "${BROKER_CFGDIR}" "${BROKER_VARDIR}" "${BROKER_LOGDIR}" "${BROKER_RUNDIR}" \
    && chmod -R g=u "${BROKER_CFGDIR}" "${BROKER_VARDIR}" "${BROKER_LOGDIR}" "${BROKER_RUNDIR}"

COPY --chown=1001:0 entrypoint.sh  /usr/local/bin/entrypoint.sh
COPY --chown=1001:0 healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chown=1001:0 templates/     /usr/local/share/centreon-broker/templates/
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

EXPOSE 5669
USER 1001:0
WORKDIR /var/lib/centreon-broker

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=4 \
  CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/cbd", "/etc/centreon-broker/central-broker.json"]
