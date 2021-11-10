### Mina Node Heatl Status Checks ###

{{/*
generic-node startup probe settings
*/}}
{{- define "healthcheck.seed.startupProbe" -}}
{{- include "healthcheck.daemon.startupProbe" . }}
{{- end -}}

{{/*
generic-node liveness settings
*/}}
{{- define "healthcheck.seed.livenessCheck" -}}
{{- include "healthcheck.daemon.livenessCheck" . }}
{{- end -}}

{{/*
generic-node readiness settings
*/}}
{{- define "healthcheck.seed.readinessCheck" }}
readinessProbe:
  exec:
    command: [
      "/bin/bash",
      "-c",
      "source /healthcheck/utilities.sh && isDaemonSynced && peerCountGreaterThan 0 && updateSyncStatusLabel {{ .name }}"
    ]
{{- end }}

{{/*
ALL generic-node healthchecks - TODO: readd startupProbes once GKE clusters have been updated to 1.16
*/}}
{{- define "healthcheck.seed.allChecks" }}
{{- if .healthcheck.enabled }}
{{- include "healthcheck.seed.livenessCheck" . }}
{{- include "healthcheck.seed.readinessCheck" . }}
{{- end }}
{{- end }}
