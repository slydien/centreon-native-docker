# Centreon Native Docker

[![Build & push images](https://github.com/example/centreon-native-docker/actions/workflows/build-images.yml/badge.svg)](https://github.com/example/centreon-native-docker/actions/workflows/build-images.yml)
[![Test](https://github.com/example/centreon-native-docker/actions/workflows/test.yml/badge.svg)](https://github.com/example/centreon-native-docker/actions/workflows/test.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Docker images and a Helm chart for [Centreon](https://www.centreon.com/) 24.10 — the monolithic-VM install split into six containers running as a single multi-container pod, deployable on Kubernetes ≥ 1.27 or OpenShift ≥ 4.12 with arbitrary UID security contexts.

The Helm chart depends on the official [Bitnami MariaDB](https://artifacthub.io/packages/helm/bitnami/mariadb) chart for the database tier.

## Architecture

Six containers, one Pod, shared volumes and PID namespace :

| Container             | PID 1 process         | Role                                       |
|-----------------------|-----------------------|--------------------------------------------|
| `mariadb`             | `mariadbd`            | `centreon` and `centreon_storage` DBs      |
| `centreon-broker-sql` | `cbd`                 | BBDO ingest → MariaDB (unified_sql)        |
| `centreon-broker-rrd` | `cbd`                 | RRD files for performance graphs           |
| `centreon-engine`     | `centengine` + cbmod  | Scheduler + checks                         |
| `centreon-gorgone`    | `gorgoned`            | Task manager (ZMQ 5556, HTTP 8085)         |
| `centreon-web`        | bash supervisor       | Apache httpd + PHP-FPM                     |

systemd is replaced by `tini` + foreground processes ; `systemctl reload centengine` is replaced by a `service` wrapper that sends `SIGHUP` through the shared PID namespace.

## Container images

All images are published to GitHub Container Registry on every push to `main` and every git tag :

```
ghcr.io/<owner>/centreon-mariadb:24.10
ghcr.io/<owner>/centreon-broker-sql:24.10
ghcr.io/<owner>/centreon-broker-rrd:24.10
ghcr.io/<owner>/centreon-engine:24.10
ghcr.io/<owner>/centreon-gorgone:24.10
ghcr.io/<owner>/centreon-web:24.10
```

Images are amd64-only (Centreon does not publish aarch64 binaries upstream).

## Quick start

### Local development (docker-compose)

```bash
cp .env.example .env
make build              # builds the six images
make compose-up         # docker-compose stack
make test-integration   # pytest against the running stack
```

### Kubernetes (Helm)

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency update ./helm/centreon

helm install centreon ./helm/centreon \
  -n centreon --create-namespace \
  -f helm/centreon/values-dev.yaml \
  --set image.registry=ghcr.io \
  --set image.repository=<owner>
```

### OpenShift (Helm)

```bash
helm install centreon ./helm/centreon \
  -n centreon --create-namespace \
  -f helm/centreon/values-openshift.yaml \
  --set image.registry=ghcr.io \
  --set image.repository=<owner> \
  --set route.host=centreon.apps.my-cluster.example.com
```

See [`helm/centreon/README.md`](helm/centreon/README.md) for the full chart reference.

## Mass provisioning

Create 500 hosts + services in parallel via the REST API :

```bash
python scripts/provisioning/mass_create_api.py --count 500 --workers 20
python scripts/provisioning/export_and_reload.py --poller 1
```

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — inter-container flows and systemd substitutions
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — OpenShift step-by-step deployment
- [`helm/centreon/README.md`](helm/centreon/README.md) — Helm chart reference

## Contributing

Issues and pull requests are welcome. The CI pipeline runs unit tests, hadolint and `helm lint` on every PR. Image builds are triggered on merges to `main` and on git tags.

## License

Apache 2.0 — see [`LICENSE`](LICENSE).
