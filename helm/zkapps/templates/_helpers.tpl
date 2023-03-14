{{/*
Expand the name of the chart.
*/}}
{{- define "mina-sample-zkapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mina-sample-zkapp.fullname" -}}
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
{{- define "mina-sample-zkapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mina-sample-zkapp.labels" -}}
helm.sh/chart: {{ include "mina-sample-zkapp.chart" . }}
{{ include "mina-sample-zkapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mina-sample-zkapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mina-sample-zkapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mina-sample-zkapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mina-sample-zkapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Job name
*/}}
{{- define "mina-sample-zkapp.job-name" -}}
{{- if .Values.suffix -}}
send-zkapps-{{ .Values.suffix }}
{{- else -}}
send-zkapps
{{- end -}}
{{- end -}}

{{/*
Service name
*/}}
{{- define "mina-sample-zkapp.service-name" -}}
{{- if .Values.suffix -}}
send-zkapps-controller-{{ .Values.suffix }}
{{- else -}}
send-zkapps-controller
{{- end -}}
{{- end -}}
