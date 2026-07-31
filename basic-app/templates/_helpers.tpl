{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "basic-deployment.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "basic-deployment.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "basic-deployment.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "basic-deployment.labels" -}}
helm.sh/chart: {{ include "basic-deployment.chart" . }}
{{ include "basic-deployment.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "basic-deployment.selectorLabels" -}}
app: {{ include "basic-deployment.name" . }}
app.kubernetes.io/name: {{ include "basic-deployment.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "basic-deployment.serviceAccountName" -}}
  {{- if .Values.serviceAccount }}
    {{- if .Values.serviceAccount.create }}
      {{- default (include "basic-deployment.fullname" .) .Values.serviceAccount.name }}
    {{- else }}
      {{- default "default" .Values.serviceAccount.name }}
    {{- end }}
  {{- else -}}
    "default"
  {{- end }}
{{- end }}

{{/*
envFrom entries (whole ConfigMap/Secret). Entries carrying `keys` are skipped
here, they are rendered as single-key env vars by basic-deployment.envKeyRefs.
*/}}
{{- define "basic-deployment.envFrom" -}}
{{- $root := . -}}
{{- range $i, $v := (.Values.envFrom | default dict).configMaps }}
{{- if not $v.keys }}
{{- if $v.data }}
- configMapRef:
    name: {{ include "basic-deployment.name" $root }}-config-env-{{ default $i $v.name }}
    optional: {{ default false $v.optional }}
{{- else if $v.name }}
- configMapRef:
    name: {{ $v.name }}
    optional: {{ default false $v.optional }}
{{- end }}
{{- end }}
{{- end }}
{{- range $i, $v := (.Values.envFrom | default dict).secrets }}
{{- if not $v.keys }}
{{- if $v.data }}
- secretRef:
    name: {{ include "basic-deployment.name" $root }}-secret-env-{{ default $i $v.name }}
    optional: {{ default false $v.optional }}
{{- else if $v.name }}
- secretRef:
    name: {{ $v.name }}
    optional: {{ default false $v.optional }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Single-key env vars from envFrom.{configMaps,secrets}[].keys.
`keys` accepts a list (env var named after the key) or a map (ENV_NAME: key).
*/}}
{{- define "basic-deployment.envKeyRefs" -}}
{{- $root := . -}}
{{- $sources := list
      (dict "items" (.Values.envFrom | default dict).configMaps "ref" "configMapKeyRef" "suffix" "config")
      (dict "items" (.Values.envFrom | default dict).secrets    "ref" "secretKeyRef"    "suffix" "secret") -}}
{{- range $src := $sources }}
{{- range $i, $v := $src.items }}
{{- if $v.keys }}
{{- $name := $v.name -}}
{{- if $v.data }}{{- $name = printf "%s-%s-env-%v" (include "basic-deployment.name" $root) $src.suffix (default $i $v.name) -}}{{- end }}
{{- $keys := dict -}}
{{- if kindIs "map" $v.keys }}{{- $keys = $v.keys -}}{{- else }}{{- range $v.keys }}{{- $_ := set $keys . . -}}{{- end }}{{- end }}
{{- range $envName, $key := $keys }}
- name: {{ $envName }}
  valueFrom:
    {{ $src.ref }}:
      name: {{ $name }}
      key: {{ $key }}
      optional: {{ default false $v.optional }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
