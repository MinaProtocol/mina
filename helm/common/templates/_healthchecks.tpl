{{/*
Liveness/readiness check common settings
*/}}
{{- define "healthcheck.common.settings" }}
initialDelaySeconds: {{ .healthcheck.initialDelaySeconds }}
periodSeconds: {{ .healthcheck.periodSeconds }}
failureThreshold: {{ .healthcheck.failureThreshold }}
{{- end }}

### Mina daemon healthcheck TEMPLATES ###

{{/*
Daemon startup probe settings
*/}}
{{- define "healthcheck.daemon.startupProbe" }}
startupProbe:
  tcpSocket:
    port: p2p-port
  failureThreshold: {{ .Values.healthcheck.failureThreshold }}
  periodSeconds: {{ .Values.healthcheck.periodSeconds }}
{{- end }}

{{/*
Daemon liveness check settings
*/}}
{{- define "healthcheck.daemon.livenessCheck" }}
livenessProbe:
  tcpSocket:
    port: p2p-port
{{- include "healthcheck.common.settings" . | indent 2 }}
{{- end }}

{{/*
Daemon readiness check settings
*/}}
{{- define "healthcheck.daemon.readinessCheck" }}
readinessProbe:
  exec:
    command: [
      "status=$(curl localhost:3085/graphql -d'{ query { daemonStatus { syncStatus } } }'); [[ status == \"synced\" ]] && return 0 || return 1"
    ]
{{- include "healthcheck.common.settings" . | indent 2 }}
{{- end }}

{{/*
ALL daemon healthchecks
*/}}
{{- define "healthcheck.daemon.allChecks" }}
{{- include "healthcheck.daemon.livenessCheck" . }}
{{- include "healthcheck.daemon.readinessCheck" . }}
{{- end }}
