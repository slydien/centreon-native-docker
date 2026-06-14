# OpenShift / Kubernetes deployment

## Prerequisites

- OpenShift 4.12+ or Kubernetes 1.27+
- A StorageClass that supports `ReadWriteOnce`
- Access to the GitHub Container Registry (default), an internal registry,
  or a public registry where the images have been pushed
- `helm` ≥ 3.13

## 1. Build and push the images

The five Centreon images are built and pushed automatically by the
`.github/workflows/build-images.yml` workflow. They land at
`ghcr.io/slydien/centreon-*:<tag>`. MariaDB is consumed from
`docker.io/bitnamilegacy/mariadb` (via the Helm chart dependency) and
is not mirrored here.

For a manual local build :

```bash
make build TAG=24.10 REGISTRY=ghcr.io NAMESPACE=slydien
make push  TAG=24.10 REGISTRY=ghcr.io NAMESPACE=slydien
```

## 2. Deploy with Helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency update ./helm/centreon

# OpenShift
helm install centreon ./helm/centreon \
  -n centreon --create-namespace \
  -f helm/centreon/values-openshift.yaml \
  --set image.registry=ghcr.io \
  --set image.repository=slydien \
  --set route.host=centreon.apps.my-cluster.example.com
```

## 3. Watch the rollout

```bash
oc get pod -n centreon -w
oc logs centreon-mariadb-0 -n centreon -f                # bitnami subchart
oc logs centreon-0 -c centreon-web -n centreon -f         # Centreon Web
```

The UI is reachable via the Route once both StatefulSets are `Ready` (~3 minutes on first install).

## 4. First login

URL : `https://centreon.apps.example.com/centreon/`

```bash
# Retrieve the admin password
oc get secret centreon-centreon-secret -n centreon \
  -o jsonpath='{.data.CENTREON_ADMIN_PASS}' | base64 -d ; echo
```

Username : `admin`.

## 5. Mass provisioning

```bash
oc port-forward -n centreon svc/centreon-web 8080:80 &
oc port-forward -n centreon svc/centreon-gorgone 8085:8085 &
python scripts/provisioning/mass_create_api.py --count 500 --workers 20
python scripts/provisioning/export_and_reload.py --poller 1
```

## Post-deployment tests

```bash
pip install -r tests/requirements.txt

# Smoke test bundled in the Helm chart
helm test centreon -n centreon

# Full pytest suite
CENTREON_URL=http://localhost:8080 \
CENTREON_ADMIN_PASS=... \
EXEC_BACKEND=kubectl POD=centreon-0 \
pytest tests/integration -m integration
```

## Troubleshooting

| Symptom                                     | Likely cause                                | Remedy                                                              |
|---------------------------------------------|---------------------------------------------|---------------------------------------------------------------------|
| mariadb CrashLoopBackOff                    | PVC not mounted, UID out of range           | `oc describe pvc data-centreon-mariadb-0` and verify the SCC        |
| centreon-engine "broker not ready"          | broker-sql not yet healthy                  | livenessProbe will retry ; tolerate `initialDelaySeconds: 60s+`     |
| 502 on the Route                            | centreon-web still importing SQL schema     | wait (~90s for first boot)                                          |
| Gorgone "no permission to write command file"| `engine-rw` volume not shared              | confirm engine AND gorgone both mount `engine-rw`                   |
| Empty RRD                                   | broker-rrd receives no events               | test `nc -vz 127.0.0.1 5670` from broker-sql, check the JSON config |

## Backup and restore

- **MariaDB** : `oc exec centreon-mariadb-0 -- mariadb-dump --all-databases > backup.sql`
- **RRD** : snapshot the `centreon-metrics-centreon-0` PVC
- **Gorgone config** : snapshot the `gorgone-data-centreon-0` PVC (contains the RSA keys)
