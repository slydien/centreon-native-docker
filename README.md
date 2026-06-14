# Centreon Native Docker

[![Build & push images](https://github.com/slydien/centreon-native-docker/actions/workflows/build-images.yml/badge.svg?branch=main)](https://github.com/slydien/centreon-native-docker/actions/workflows/build-images.yml)
[![Test](https://github.com/slydien/centreon-native-docker/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/slydien/centreon-native-docker/actions/workflows/test.yml)
[![Release Helm chart](https://github.com/slydien/centreon-native-docker/actions/workflows/helm-release.yml/badge.svg)](https://github.com/slydien/centreon-native-docker/actions/workflows/helm-release.yml)
[![Latest release](https://img.shields.io/github/v/release/slydien/centreon-native-docker?sort=semver)](https://github.com/slydien/centreon-native-docker/releases)
[![License](https://img.shields.io/github/license/slydien/centreon-native-docker)](LICENSE)

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
ghcr.io/slydien/mariadb:24.10.27
ghcr.io/slydien/centreon-broker-sql:24.10.27
ghcr.io/slydien/centreon-broker-rrd:24.10.27
ghcr.io/slydien/centreon-engine:24.10.27
ghcr.io/slydien/centreon-gorgone:24.10.27
ghcr.io/slydien/centreon-web:24.10.27
```

Each image is also tagged `:24.10`, `:24`, `:latest` (highest semver) and
`:main` / `:sha-<short>` for development builds.

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
  -f helm/centreon/values-dev.yaml
```

### OpenShift (Helm)

```bash
helm install centreon ./helm/centreon \
  -n centreon --create-namespace \
  -f helm/centreon/values-openshift.yaml \
  --set route.host=centreon.apps.my-cluster.example.com
```

### From the OCI chart registry

A packaged chart is published on every release :

```bash
helm install centreon \
  oci://ghcr.io/slydien/charts/centreon \
  --version 24.10.27 \
  -n centreon --create-namespace
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

## Releasing a new Centreon version

Every release is driven by a single git tag. Pushing `v24.10.27` (or any
`vX.Y.Z`) triggers two parallel workflows that publish artefacts pinned to
that exact Centreon version :

```
       git tag v24.10.27 && git push --tags
                       │
        ┌──────────────┴──────────────┐
        ▼                             ▼
 build-images.yml             helm-release.yml
   • CENTREON_VERSION=24.10.27   • Chart.yaml : appVersion + version = 24.10.27
   • repo URL: rpm-standard/24.10/   • values.yaml : image.tag = 24.10.27
   • image tags :                    • helm package → centreon-24.10.27.tgz
       :24.10.27, :24.10, :24, :latest   • push  oci://ghcr.io/slydien/charts/centreon:24.10.27
                                     • GitHub Release with the chart attached
```

To support a different release :

```bash
git tag v24.10.30
git push --tags        # triggers the full pipeline for 24.10.30
```

The `CENTREON_VERSION` build-arg accepts either a `MAJOR.MINOR` branch
(`24.10`) or a full `MAJOR.MINOR.PATCH` release (`24.10.27`). Only the
`MAJOR.MINOR` part ends up in the Centreon repo URL, so the actual installed
patch is the most recent one available in that branch at build time. The
image tag and OCI labels always carry the requested full version.

## Contributing

Issues and pull requests are welcome. The CI pipeline runs unit tests,
hadolint and `helm lint` on every PR. Image builds are triggered on merges
to `main` and on git tags.

## License

Apache 2.0 — see [`LICENSE`](LICENSE).
