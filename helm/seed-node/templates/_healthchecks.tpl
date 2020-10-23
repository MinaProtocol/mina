### Mina Seed node healthcheck TEMPLATES ###

{{/*
seed-node startup probe settings
*/}}
{{- define "healthcheck.seed.startupProbe" -}}
{{ include "healthcheck.daemon.startupProbe" . }}
{{- end -}}

{{/*
seed-node liveness settings
*/}}
{{- define "healthcheck.seed.livenessCheck" -}}
{{ include "healthcheck.daemon.livenessCheck" . }}
{{- end -}}

{{/*
seed-node readiness settings
*/}}
{{- define "healthcheck.seed.readinessCheck" -}}
{{ include "healthcheck.daemon.readinessCheck" . }}
{{- end -}}

{{/*
ALL seed-node healthchecks
*/}}
{{- define "healthcheck.seed.allChecks" }}
{{ include "healthcheck.seed.livenessCheck" . }}
{{ include "healthcheck.seed.readinessCheck" . }}
{{- end }}
