### Mina SNARK-worker healthcheck TEMPLATES ###

{{/*
snark-worker startup probe settings
*/}}
{{- define "healthcheck.snarkWorker.startupProbe" -}}
{{ include "healthcheck.daemon.startupProbe" . }}
{{- end -}}

{{/*
snark-worker liveness settings
*/}}
{{- define "healthcheck.snarkWorker.livenessCheck" -}}
{{ include "healthcheck.daemon.livenessCheck" . }}
{{- end -}}

{{/*
snark-worker readiness settings
*/}}
{{- define "healthcheck.snarkWorker.readinessCheck" -}}
{{ include "healthcheck.daemon.readinessCheck" . }}
{{- end -}}
