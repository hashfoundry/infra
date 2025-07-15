{{/*
Expand the name of the chart.
*/}}
{{- define "nfs-provisioner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "nfs-provisioner.fullname" -}}
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
{{- define "nfs-provisioner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nfs-provisioner.labels" -}}
helm.sh/chart: {{ include "nfs-provisioner.chart" . }}
{{ include "nfs-provisioner.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nfs-provisioner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nfs-provisioner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
NFS Server labels
*/}}
{{- define "nfs-provisioner.nfsServerLabels" -}}
{{ include "nfs-provisioner.labels" . }}
app.kubernetes.io/component: nfs-server
{{- end }}

{{/*
NFS Provisioner labels
*/}}
{{- define "nfs-provisioner.provisionerLabels" -}}
{{ include "nfs-provisioner.labels" . }}
app.kubernetes.io/component: nfs-provisioner
{{- end }}
