# Centreon Helm chart

Deploys Centreon 24.10 on Kubernetes ≥ 1.27 and OpenShift ≥ 4.12.

* The **Centreon stack** (broker-sql, broker-rrd, engine, gorgone, web) runs
  as a single multi-container StatefulSet (1 replica).
* **MariaDB** is consumed as a dependency on the official Bitnami chart.
* External exposure : **ClusterIP** + Ingress (vanilla K8s) or Route (OpenShift).
* No custom SCC : compatible with `restricted-v2` (arbitrary UID).

## Prerequisites

| Tool      | Version  |
|-----------|----------|
| Kubernetes| ≥ 1.27   |
| OpenShift | ≥ 4.12   |
| Helm      | ≥ 3.13   |
| StorageClass with ReadWriteOnce | required |

## Installation

```bash
# 1. Add the Bitnami repo and pull dependencies
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency update ./helm/centreon

# 2. Install
# -------- Vanilla Kubernetes (kind, minikube, EKS…) --------
helm install centreon ./helm/centreon \
  -n centreon --create-namespace \
  -f helm/centreon/values-dev.yaml

# -------- OpenShift --------
helm install centreon ./helm/centreon \
  -n centreon --create-namespace \
  -f helm/centreon/values-openshift.yaml \
  --set route.host=centreon.apps.my-cluster.example.com
```

## Architecture

```
   Ingress / Route  --►  centreon-web (Service ClusterIP :80)
                              │
                              ▼  shareProcessNamespace: true
   ┌──────────────── StatefulSet centreon ────────────────┐
   │  centreon-web      (httpd + php-fpm)                 │
   │  centreon-gorgone  (task manager)                    │
   │  centreon-engine   (centengine + cbmod)              │
   │  centreon-broker-sql (cbd → MariaDB)                 │
   │  centreon-broker-rrd (cbd → RRD files)               │
   └──────────────────────────────────────────────────────┘
                              │ TCP 3306
                              ▼
              ┌─────────── StatefulSet release-mariadb ──────┐
              │  bitnami/mariadb (1 replica, standalone)     │
              └──────────────────────────────────────────────┘
```

| Volume          | Type     | Containers                                       |
|-----------------|----------|--------------------------------------------------|
| engine-config   | emptyDir | engine + gorgone + web                           |
| engine-rw       | emptyDir | engine + gorgone                                 |
| broker-config   | emptyDir | engine + broker-sql + web                        |
| broker-data     | emptyDir | engine + broker-sql + broker-rrd                 |
| centreon-etc    | PVC      | web                                              |
| centreon-metrics| PVC      | broker-rrd + web                                 |
| gorgone-data    | PVC      | gorgone                                          |
| mariadb data    | PVC      | bitnami/mariadb subchart                         |

## Values

See [`values.yaml`](./values.yaml) for the complete list and
[`values-dev.yaml`](./values-dev.yaml) / [`values-openshift.yaml`](./values-openshift.yaml)
for example overlays.

Main keys :

| Key | Default | Description |
|-----|---------|-------------|
| `image.registry` | `ghcr.io` | Container registry |
| `image.repository` | `slydien` | Owner / namespace within the registry |
| `image.tag` | `24.10` | Shared tag for the 5 Centreon images |
| `image.pullSecrets` | `[]` | imagePullSecrets |
| `mariadb.enabled` | `true` | Disable to point at an external DB (see below) |
| `mariadb.auth.password` | `""` | Empty → stable random password |
| `centreon.admin.password` | `""` | Empty → stable random password |
| `secrets.create` | `true` | Create the Centreon Secret (else `existingSecret`) |
| `secrets.existingSecret` | `""` | Name of an external Secret (External Secrets Operator, Conjur…) |
| `persistence.enabled` | `true` | PVCs for Centreon (the DB is owned by bitnami) |
| `persistence.storageClass` | `""` | Empty → cluster default StorageClass |
| `ingress.enabled` | `false` | Vanilla K8s Ingress |
| `route.enabled` | `false` | OpenShift Route |
| `shareProcessNamespace` | `true` | Required by the SIGHUP reload (systemctl substitute) |

## Retrieve the admin password

If you didn't set `centreon.admin.password`, a random 24-character password
is generated on first `helm install` and stored in the Centreon Secret.
Retrieve it with :

```bash
kubectl get secret -n centreon \
  $(helm get values centreon -n centreon --output json | jq -r '.secrets.existingSecret // "centreon-centreon-secret"') \
  -o jsonpath='{.data.CENTREON_ADMIN_PASS}' | base64 -d ; echo
```

The Secret is annotated `helm.sh/resource-policy: keep` → it survives a
`helm uninstall` and the password remains stable on reinstall in the same
namespace.

## External Secret

If you use an external Secret (External Secrets Operator, CyberArk Conjur,
HashiCorp Vault…) :

```yaml
secrets:
  create: false
  existingSecret: my-centreon-secret  # contains CENTREON_ADMIN_PASS

mariadb:
  auth:
    existingSecret: my-mariadb-secret # contains mariadb-root-password, mariadb-password
```

See the Bitnami MariaDB docs for the keys expected inside `mariadb.auth.existingSecret`.

## External DB (mariadb.enabled=false)

To point at an external MariaDB (RDS, MariaDB Operator, etc.) :

```yaml
mariadb:
  enabled: false      # do not install the bitnami sub-chart

# The chart still uses `<release>-mariadb` as the default hostname.
# To target a different host, create an ExternalName Service :
#   apiVersion: v1
#   kind: Service
#   metadata: { name: centreon-mariadb }
#   spec:
#     type: ExternalName
#     externalName: my-external-mariadb.db.svc.cluster.local
```

The DB must have : a `centreon` user with its password stored in the
`<release>-mariadb` Secret (key `mariadb-password`), and both `centreon` +
`centreon_storage` databases created with full privileges on each.

## Smoke tests

```bash
helm test centreon -n centreon
```

Runs a Pod that curls the `/installation/status` (web) and
`/api/internal/information` (gorgone) endpoints and asserts they respond.

## Upgrade

```bash
helm upgrade centreon ./helm/centreon -n centreon \
  --reuse-values --set image.tag=24.10.30
```

Checksums on ConfigMap/Secret trigger a rolling pod restart when the
config changes. The StatefulSet reuses the existing PVCs.

## Uninstall

```bash
helm uninstall centreon -n centreon
```

PVCs and the Secret are **not deleted** (annotation `resource-policy: keep`).
To wipe everything :

```bash
kubectl delete pvc -n centreon -l app.kubernetes.io/instance=centreon
kubectl delete pvc -n centreon -l app.kubernetes.io/instance=centreon,app.kubernetes.io/name=mariadb
kubectl delete secret -n centreon centreon-centreon-secret
```

## Lint / template

```bash
helm dependency update ./helm/centreon
helm lint ./helm/centreon -f helm/centreon/values-dev.yaml
helm template centreon ./helm/centreon -f helm/centreon/values-dev.yaml | \
  kubectl apply --dry-run=client -f -
```

## Limitations

- **Single replica** : Centreon Central is not designed for active-active HA.
  For HA, see centreon-ha (out of scope for this chart).
- **shareProcessNamespace: true** : required by the `service` wrapper in
  centreon-web → SIGHUP centengine. Incompatible with any SCC that forbids
  this flag (very rare ; `restricted-v2` allows it).
