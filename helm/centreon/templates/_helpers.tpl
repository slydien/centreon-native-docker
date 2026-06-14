{{/* vim: set filetype=mustache: */}}

{{- define "centreon.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "centreon.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "centreon.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to every resource.
*/}}
{{- define "centreon.labels" -}}
helm.sh/chart: {{ include "centreon.chart" . }}
{{ include "centreon.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: monitoring
{{- end -}}

{{- define "centreon.selectorLabels" -}}
app.kubernetes.io/name: {{ include "centreon.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Build the full image reference for a given component.
Usage:
  {{ include "centreon.image" (dict "ctx" . "component" "web") }}
*/}}
{{- define "centreon.image" -}}
{{- $ctx := .ctx -}}
{{- $component := .component -}}
{{- $perImage := index $ctx.Values.image $component -}}
{{- $names := dict
    "brokerSql" "centreon-broker-sql"
    "brokerRrd" "centreon-broker-rrd"
    "engine"    "centreon-engine"
    "gorgone"   "centreon-gorgone"
    "web"       "centreon-web"
-}}
{{- $imageName := index $names $component -}}
{{- $repo := $perImage.repository -}}
{{- if not $repo -}}
{{- $repo = printf "%s/%s/%s" $ctx.Values.image.registry $ctx.Values.image.repository $imageName -}}
{{- end -}}
{{- $tag := $perImage.tag -}}
{{- if not $tag -}}
{{- $tag = $ctx.Values.image.tag -}}
{{- end -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}

{{/*
Centreon Secret name (either chart-managed or pre-existing).
*/}}
{{- define "centreon.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-centreon-secret" (include "centreon.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
MariaDB Service name (provided by the bitnami sub-chart).
When used as a sub-chart, bitnami names its primary service "<release>-mariadb".
We always rely on that DNS name.
*/}}
{{- define "centreon.mariadbHost" -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- end -}}

{{/*
MariaDB Secret name (managed by the bitnami sub-chart).
Same naming convention.
*/}}
{{- define "centreon.mariadbSecretName" -}}
{{- if .Values.mariadb.auth.existingSecret -}}
{{- .Values.mariadb.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-mariadb" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Keep a value stable across upgrades : .value if set, else read from an
existing Secret on the cluster, else a random 24-char alphanumeric string.
Usage:
  {{ include "centreon.passwordOrRandom" (dict "ctx" . "value" .Values.centreon.admin.password "key" "CENTREON_ADMIN_PASS") }}
*/}}
{{- define "centreon.passwordOrRandom" -}}
{{- $ctx := .ctx -}}
{{- if .value -}}
{{- .value -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" $ctx.Release.Namespace (include "centreon.secretName" $ctx) -}}
{{- if and $existing $existing.data (index $existing.data .key) -}}
{{- index $existing.data .key | b64dec -}}
{{- else -}}
{{- randAlphaNum 24 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Storage class for a Centreon PVC ; falls back to the global value, then to
empty (cluster default).
Usage : {{ include "centreon.storageClass" (dict "ctx" . "pvc" "centreonEtc") }}
*/}}
{{- define "centreon.storageClass" -}}
{{- $ctx := .ctx -}}
{{- $pvc := index $ctx.Values.persistence .pvc -}}
{{- if and $pvc $pvc.storageClass -}}
{{- $pvc.storageClass -}}
{{- else if $ctx.Values.persistence.storageClass -}}
{{- $ctx.Values.persistence.storageClass -}}
{{- end -}}
{{- end -}}
