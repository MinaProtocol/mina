### Mina Archive-Node healthcheck TEMPLATES ###

{{/*
archive-node startup probe settings
*/}}
{{- define "healthcheck.archive.startupProbe" }}
startupProbe:
  tcpSocket:
    port: postgres-port
{{- end }}

{{/*
archive-node liveness check settings
*/}}
{{- define "healthcheck.archive.livenessCheck" }}
livenessProbe:
  tcpSocket:
    port: archive-port
{{- include "healthcheck.common.settings" . | indent 2 }}
{{- end }}

{{/*
archive-node readiness check settings
*/}}
{{- define "healthcheck.archive.readinessCheck" }}
readinessProbe:
  exec:
    command: [
      "/bin/bash",
      "-c",
      "source /healthcheck/utilities.sh && isArchiveSynced --db-host {{ tpl .Values.archive.postgresHost . }}"
    ]
{{- include "healthcheck.common.settings" .Values | indent 2 }}
{{- end }}

{{/*
ALL archive-node healthchecks  - TODO: readd startupProbes once GKE clusters have been updated to 1.16
*/}}
{{- define "healthcheck.archive.allChecks" }}
{{- if .Values.healthcheck.enabled }}
{{- include "healthcheck.archive.livenessCheck" .Values }}
{{- if .Values.archive.enableLocalDaemon }}
{{- include "healthcheck.archive.readinessCheck" . }}
{{- end }}
{{- end }}
{{- end }}
