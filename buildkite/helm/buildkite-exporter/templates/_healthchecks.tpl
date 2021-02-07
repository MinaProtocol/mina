### O(1) Lab's Buildkite Exporter healthcheck TEMPLATES ###

{{/*
buildkite-exporter startup probe settings
*/}}
{{- define "healthcheck.buildkite-exporter.startupProbe" }}
startupProbe:
  tcpSocket:
    port: metrics-port
  failureThreshold: 30
  periodSeconds: 10
{{- end }}

{{/*
buildkite-exporter liveness check settings
*/}}
{{- define "healthcheck.buildkite-exporter.livenessCheck" }}
livenessProbe:
  tcpSocket:
    port: metrics-port
{{- include "healthcheck.common.settings" . | indent 2 }}
{{- end }}

{{/*
buildkite-exporter readiness check settings
*/}}
{{- define "healthcheck.buildkite-exporter.readinessCheck" }}
readinessProbe:
  exec:
    command:
      - "curl"
      - "localhost:{{ .exporter.ports.metricsPort }}/metrics"
  initialDelaySeconds: {{ .healthcheck.initialDelaySeconds }}
  periodSeconds: 60
  failureThreshold: 5
{{- end }}

{{/*
ALL buildkite-exporter healthchecks - TODO: readd startupProbes once GKE clusters have been updated to 1.16
*/}}
{{- define "healthcheck.buildkite-exporter.healthChecks" }}
{{- include "healthcheck.buildkite-exporter.livenessCheck" . }}
{{- include "healthcheck.buildkite-exporter.readinessCheck" . }}
{{- end }}
