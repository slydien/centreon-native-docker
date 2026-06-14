# Architecture

## Overview

The Centreon pod groups six containers whose internal data flows match a
standard monolithic VM install. The key difference: no systemd, and every
component runs under an arbitrary UID.

```
                      ┌────────────────────────────┐
   OpenShift Route ──▶│  centreon-web (httpd+PHP)  │
                      │  :8080                     │
                      └──────┬──────────────┬──────┘
                             │ SQL          │ HTTP
                             ▼              ▼
                      ┌──────────────┐ ┌──────────────────┐
                      │   mariadb    │ │ centreon-gorgone │
                      │   :3306      │ │ :8085 (HTTP)     │
                      └──────▲───────┘ │ :5556 (ZMQ)      │
                             │         └──┬───────────────┘
                  SQL writes │            │ write cmd file
                             │            ▼
                      ┌──────┴────────┐ ┌──────────────────┐
                      │ centreon-     │ │ centreon-engine  │
   BBDO 5670   ┌─────▶│ broker-sql    │◀┤ + cbmod          │
       ┌───────┘ 5669 │               │ │                  │
       │              └───────────────┘ └────────┬─────────┘
       │                                         │
┌──────┴──────────┐                              │ SIGHUP / cmd file
│ centreon-broker │                              │ via volume engine-rw
│       -rrd      │◀─────────────────────────────┘
│   :5670 BBDO    │
│   ↓ RRD files   │
└─────────────────┘
       │
       └─ writes /var/lib/centreon/metrics → PVC shared with centreon-web
```

## systemd substitutions

| VM mechanism (systemd)              | Container equivalent                                                |
|-------------------------------------|---------------------------------------------------------------------|
| `systemctl start centengine`        | `centengine` launched by tini as PID 1                              |
| `systemctl reload centengine`       | `service` wrapper sends `SIGHUP` via shared PID namespace (`shareProcessNamespace: true`) |
| `systemctl start cbd-sql`, `cbd-rrd`| Two distinct `cbd` containers with separate configs                 |
| `systemctl start gorgoned`          | `gorgoned` runs in foreground in its container                      |
| `systemctl start httpd` + `php-fpm` | `supervisor.sh` (bash) launches both, exits when either dies        |
| `journalctl -u centengine`          | logs go to stdout → kubelet → Loki/CloudWatch/etc.                  |

## Shared volumes (pod-local emptyDir)

| Volume         | Containers                  | Purpose                                                                  |
|----------------|-----------------------------|--------------------------------------------------------------------------|
| `engine-config`| engine + gorgone + web      | `/etc/centreon-engine/*.cfg` pushed by Gorgone on each export            |
| `engine-rw`    | engine + gorgone            | command file `centengine.cmd_read` (FIFO created by centengine)         |
| `broker-config`| engine + broker-sql + web   | broker JSON configs (cbmod on the engine side)                          |
| `broker-data`  | engine + broker-sql + broker-rrd | sockets and caches                                                 |

## Persistent volumes (PVC)

| PVC                | Container        | Rationale                                              |
|--------------------|------------------|--------------------------------------------------------|
| `mariadb-data`     | mariadb          | DB data (config + history)                             |
| `centreon-etc`     | web              | `/etc/centreon` — certificates, local config           |
| `centreon-metrics` | broker-rrd + web | RRD files for performance graphs                       |
| `gorgone-data`     | gorgone          | RSA keys + task history                                |

## OpenShift security

- No container requests `--privileged`
- No capabilities required (all dropped)
- All containers run as `runAsNonRoot: true`, arbitrary UID (≥ 1000), group 0
- No port < 1024 (httpd listens on 8080)
- `readOnlyRootFilesystem` ready : every write goes to `/var/lib/*`,
  `/var/log/*`, `/var/run/*` (mounted as emptyDir)
- Secrets injectable via CyberArk Conjur or Kubernetes Secret

## Startup ordering

1. **initContainer** `prepare-shared-dirs` : sets permissions on the shared
   emptyDir volumes.
2. **initContainer** `wait-for-mariadb` : TCP-checks the MariaDB service.
3. **mariadb** : healthy when `SELECT 1` succeeds.
4. **centreon-broker-sql** : waits for MariaDB → opens BBDO 5669.
5. **centreon-broker-rrd** : opens BBDO 5670.
6. **centreon-engine** : waits for broker-sql:5669 → starts centengine.
7. **centreon-gorgone** : waits for MariaDB → opens HTTP 8085 and ZMQ 5556.
8. **centreon-web** : waits for MariaDB → imports SQL schema if DB is empty,
   starts the supervisor (httpd + php-fpm).

Kubernetes `livenessProbe` and `readinessProbe` ensure the pod exposes its
Route only once every container is ready.
