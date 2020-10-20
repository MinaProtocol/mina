### Mina Archive-Node healthcheck TEMPLATES ###

{{/*
archive-node startup probe settings
*/}}
{{- define "healthcheck.archive.startupProbe" -}}
startupProbe:
  tcpSocket:
    port: archive-postgres
  failureThreshold: {{- default 60 .Values.healthcheck.failureThreshold -}}
  periodSeconds: {{- default 5 .Values.healthcheck.periodSeconds -}}
{{- end -}}

{{/*
archive-node liveness check settings
*/}}
{{- define "healthcheck.archive.livenessCheck" -}}
livenessProbe:
  tcpSocket:
    port: archive-server
  {{ template "healthcheck.common.settings" . }}
{{- end -}}

{{/*
archive-node readiness check settings
*/}}
{{- define "healthcheck.archive.readinessCheck" -}}
readinessProbe:
  exec:
    command: "<postgres-query>"
  {{ template "healthcheck.common.settings" . }}
{{- end -}}

{{/*
ALL archive-node healthchecks
*/}}
{{- define "healthcheck.archive.healthChecks" -}}
{{ template "healthcheck.archive.startupProbe" . }}
{{ template "healthcheck.archive.livenessCheck" . }}
{{ template "healthcheck.archive.readinessCheck" . }}
{{- end -}}
