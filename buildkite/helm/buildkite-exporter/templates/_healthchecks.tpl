### O(1) Lab's Buildkite Exporter healthcheck TEMPLATES ###

{{/*
buildkite-exporter startup probe settings
*/}}
{{- define "healthcheck.buildkite-exporter.startupProbe" -}}
startupProbe:
  tcpSocket:
    port: metrics-port
  failureThreshold: {{- default 60 .Values.healthcheck.failureThreshold -}}
  periodSeconds: {{- default 5 .Values.healthcheck.periodSeconds -}}
{{- end -}}

{{/*
buildkite-exporter liveness check settings
*/}}
{{- define "healthcheck.buildkite-exporter.livenessCheck" -}}
livenessProbe:
  tcpSocket:
    port: metrics-port
  {{ template "healthcheck.common.settings" . }}
{{- end -}}

{{/*
buildkite-exporter readiness check settings
*/}}
{{- define "healthcheck.buildkite-exporter.readinessCheck" -}}
readinessProbe:
  exec:
    command: "curl localhost:{{ .Values.exporter.ports.metricsPort }}/metrics"
    {{ template "healthcheck.common.settings" . }}
{{- end -}}

{{/*
ALL buildkite-exporter healthchecks
*/}}
{{- define "healthcheck.buildkite-exporter.healthChecks" -}}
{{ template "healthcheck.buildkite-exporter.startupProbe" . }}
{{ template "healthcheck.buildkite-exporter.livenessCheck" . }}
{{ template "healthcheck.buildkite-exporter.readinessCheck" . }}
{{- end -}}
