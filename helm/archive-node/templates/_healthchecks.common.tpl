{{/*
Liveness/readiness check common settings
*/}}
{{- define "healthcheck.common.settings" -}}
initialDelaySeconds: {{- default 30 .Values.healthcheck.initialDelaySeconds -}}
periodSeconds: {{- default 10 .Values.healthcheck.periodSeconds -}}
failureThreshold: {{- default 3 .Values.healthcheck.failureThreshold -}}
{{- end -}}

### Mina daemon healthcheck TEMPLATES ###

{{/*
Daemon startup probe settings
*/}}
{{- define "healthcheck.daemon.startupProbe" -}}
startupProbe:
  tcpSocket:
    port: libp2p-port
  failureThreshold: {{- default 60 .Values.healthcheck.failureThreshold -}}
  periodSeconds: {{- default 5 .Values.healthcheck.periodSeconds -}}
{{- end -}}

{{/*
Daemon liveness check settings
*/}}
{{- define "healthcheck.daemon.livenessCheck" -}}
livenessProbe:
  tcpSocket:
    port: libp2p-port
  {{ template "healthcheck.common.settings" . }}
{{- end -}}

{{/*
Daemon readiness check settings
*/}}
{{- define "healthcheck.daemon.readinessCheck" -}}
readinessProbe:
  exec:
    command: "status=$(curl localhost:3085/graphql -d'{ query { daemonStatus { syncStatus } } }'); [[ status == \"synced\" ]] && return 0 || return 1"
  {{ template "healthcheck.common.settings" . }}
{{- end -}}

{{/*
ALL daemon healthchecks
*/}}
{{- define "healthcheck.daemon.healthChecks" -}}
{{ template "healthcheck.daemon.startupProbe" . }}
{{ template "healthcheck.daemon.livenessCheck" . }}
{{ template "healthcheck.daemon.readinessCheck" . }}
{{- end -}}
