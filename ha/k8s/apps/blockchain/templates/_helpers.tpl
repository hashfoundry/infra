{{/*
Expand the name of the chart.
*/}}
{{- define "blockchain.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "blockchain.fullname" -}}
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
{{- define "blockchain.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "blockchain.labels" -}}
helm.sh/chart: {{ include "blockchain.chart" . }}
{{ include "blockchain.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: hashfoundry
{{- end }}

{{/*
Selector labels
*/}}
{{- define "blockchain.selectorLabels" -}}
app.kubernetes.io/name: {{ include "blockchain.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Alice validator labels
*/}}
{{- define "blockchain.aliceLabels" -}}
{{ include "blockchain.labels" . }}
app.kubernetes.io/component: validator-alice
{{- end }}

{{/*
Alice validator selector labels
*/}}
{{- define "blockchain.aliceSelectorLabels" -}}
{{ include "blockchain.selectorLabels" . }}
app.kubernetes.io/component: validator-alice
{{- end }}

{{/*
Bob validator labels
*/}}
{{- define "blockchain.bobLabels" -}}
{{ include "blockchain.labels" . }}
app.kubernetes.io/component: validator-bob
{{- end }}

{{/*
Bob validator selector labels
*/}}
{{- define "blockchain.bobSelectorLabels" -}}
{{ include "blockchain.selectorLabels" . }}
app.kubernetes.io/component: validator-bob
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "blockchain.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "blockchain.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Alice validator full name
*/}}
{{- define "blockchain.aliceFullname" -}}
{{- printf "%s-alice" (include "blockchain.fullname" .) }}
{{- end }}

{{/*
Bob validator full name
*/}}
{{- define "blockchain.bobFullname" -}}
{{- printf "%s-bob" (include "blockchain.fullname" .) }}
{{- end }}

{{/*
Namespace name
*/}}
{{- define "blockchain.namespace" -}}
{{- default "blockchain" .Values.namespace }}
{{- end }}
