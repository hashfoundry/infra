{{/*
Expand the name of the chart.
*/}}
{{- define "substrate-blockchain.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "substrate-blockchain.fullname" -}}
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
{{- define "substrate-blockchain.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "substrate-blockchain.labels" -}}
helm.sh/chart: {{ include "substrate-blockchain.chart" . }}
{{ include "substrate-blockchain.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "substrate-blockchain.selectorLabels" -}}
app.kubernetes.io/name: {{ include "substrate-blockchain.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "substrate-blockchain.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "substrate-blockchain.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate node key for a validator
*/}}
{{- define "substrate-blockchain.nodeKey" -}}
{{- if eq .Values.nodeKeyStrategy "fixed" }}
{{- if eq .role "alice" }}
{{- .Values.nodeKeys.alice }}
{{- else if eq .role "bob" }}
{{- .Values.nodeKeys.bob }}
{{- else }}
{{- printf "000000000000000000000000000000000000000000000000000000000000000%d" .index }}
{{- end }}
{{- else }}
{{- printf "generated-%s-%s" .Release.Name .role }}
{{- end }}
{{- end }}

{{/*
Generate peer ID from node key (simplified - in real implementation would use proper crypto)
*/}}
{{- define "substrate-blockchain.peerId" -}}
{{- if eq .role "alice" }}
12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp
{{- else if eq .role "bob" }}
12D3KooWHdiAxVd8uMQR1hGWXccidmfCwLqcMpGwR6QcTP6QRMuD
{{- else }}
{{- printf "12D3KooW%s" (randAlphaNum 40) }}
{{- end }}
{{- end }}

{{/*
Generate bootnodes string for a validator
*/}}
{{- define "substrate-blockchain.bootnodes" -}}
{{- $bootnodes := list }}
{{- if and .config.bootnodes .config.bootnodes.enabled }}
{{- range .config.bootnodes.static }}
{{- $serviceName := printf "%s-%s" $.fullname .service }}
{{- $bootnode := printf "/dns4/%s.%s.svc.cluster.local/tcp/%d/p2p/%s" $serviceName $.namespace (int .port) .peerId }}
{{- $bootnodes = append $bootnodes $bootnode }}
{{- end }}
{{- end }}
{{- join "," $bootnodes }}
{{- end }}

{{/*
Generate substrate command arguments
*/}}
{{- define "substrate-blockchain.args" -}}
- --chain={{ .Values.global.network.chainType }}
- --validator
- --{{ .role }}
- --base-path={{ .config.nodeConfig.basePath }}
- --rpc-external
- --rpc-port={{ .config.service.ports.rpcHttp }}
- --rpc-cors={{ .config.nodeConfig.rpcCors }}
- --rpc-methods={{ .config.nodeConfig.rpcMethods }}
- --ws-external
- --ws-port={{ .config.service.ports.rpcWs }}
- --unsafe-rpc-external
- --unsafe-ws-external
- --port={{ .config.service.ports.p2p }}
- --name={{ .config.nodeConfig.name }}
{{- if eq .Values.nodeKeyStrategy "fixed" }}
- --node-key={{ include "substrate-blockchain.nodeKey" (dict "Values" .Values "role" .role "index" .index) }}
{{- end }}
{{- $bootnodes := include "substrate-blockchain.bootnodes" (dict "config" .config "namespace" .namespace "fullname" .fullname "Values" .Values) }}
{{- if $bootnodes }}
- --bootnodes={{ $bootnodes }}
{{- end }}
{{- end }}

{{/*
Generate environment variables
*/}}
{{- define "substrate-blockchain.env" -}}
- name: RUST_LOG
  value: "info"
- name: RUST_BACKTRACE
  value: "1"
{{- if ne .Values.nodeKeyStrategy "fixed" }}
- name: NODE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "substrate-blockchain.fullname" . }}-node-keys
      key: {{ .role }}-key
{{- end }}
{{- end }}

{{/*
Generate volume mounts
*/}}
{{- define "substrate-blockchain.volumeMounts" -}}
- name: blockchain-data
  mountPath: {{ .config.nodeConfig.basePath }}
{{- if ne .nodeKeyStrategy "fixed" }}
- name: node-key
  mountPath: /tmp/node-key
  subPath: node-key
  readOnly: true
{{- end }}
{{- end }}

{{/*
Generate volumes
*/}}
{{- define "substrate-blockchain.volumes" -}}
{{- if ne .nodeKeyStrategy "fixed" }}
- name: node-key
  secret:
    secretName: {{ .fullname }}-node-keys
    items:
    - key: {{ .role }}-key
      path: node-key
{{- end }}
{{- end }}
