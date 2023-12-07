{{/*
Expand the name of the chart.
*/}}
{{- define "ci-dashboard.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ci-dashboard.fullname" -}}
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
{{- define "ci-dashboard.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ci-dashboard.labels" -}}
helm.sh/chart: {{ include "ci-dashboard.chart" . }}
{{ include "ci-dashboard.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ci-dashboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ci-dashboard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ci-dashboard.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ci-dashboard.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Create a standard "retriever" container. It includes:
- envs
- volumeMounts: scripts in Secrets
    - Passed as {name: n, mountPath: p}
*/}}
{{- define "ci-dashboard.insertRetriever" -}}
{{- $retrieverName := .retriever.name -}}
{{- $outputEnvName := .root.Values.outputEnv.name -}}
{{- $outputPath := (printf "%s/%s" .root.Values.outputEnv.value $retrieverName) -}}
- name: "{{ $retrieverName }}-retriever"
  image: {{ .retriever.image.name }}:{{ .retriever.image.tag }}
  imagePullPolicy: IfNotPresent
  {{- with .retriever.env }}
  env:
  {{- . | toYaml | nindent 2 }}
  {{- end }}
  - name: {{ $outputEnvName | upper | quote }}
    value: {{ $outputPath | quote }}
  volumeMounts:
  {{- with .retriever.script }}
  - name: {{ .secret.name | quote }}
    mountPath: {{ .mountPath | quote }}
  {{- end }}
  - name: {{ $outputEnvName | quote }}
    mountPath: {{ .root.Values.outputEnv.value | quote }}
  command:
  - /bin/bash
  args:
  - -c
  - '
      echo "Bootstrapping {{ .retriever.name }} retriever environment";
      pip install -r {{ .retriever.script.mountPath }}/requirements.txt;
      /usr/local/bin/python -u {{ .retriever.script.mountPath }}/{{ .retriever.script.name }};
    '
{{- end }}

{{/*
Inserting automatically created Secrets to Retriever Pod
Also adding .Values.outputEnv Volume to Pod
*/}}
{{- define "ci-dashboard.insertRetrieverVolumes" -}}
{{- range $i, $retriever := .Values.retrievers }}
{{- with $retriever.script.secret }}
- name: {{ .name | quote }}
  secret:
    secretName: {{ .name | quote }}
{{- end }}
{{- end }}
{{- with .Values.outputEnv }}
- name: {{ .name | quote }}
  {{- .volume | toYaml | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Inserting .Values.dbPusher associated Volumes
*/}}
{{- define "ci-dashboard.insertDbPusherVolume" -}}
- name: {{ .Values.dbPusher.script.secret.name | quote }}
  secret:
    secretName: {{ .Values.dbPusher.script.secret.name | quote }}
{{- end }}