### Mina SNARK-coordinator/worker healthcheck TEMPLATES ###

{{/*
snark-coordinator startup probe settings
*/}}
{{- define "healthcheck.snarkCoordinator.startupProbe" -}}
{{- include "healthcheck.daemon.startupProbe" . }}
{{- end -}}

{{/*
snark-coordinator liveness settings
*/}}
{{- define "healthcheck.snarkCoordinator.livenessCheck" -}}
{{- include "healthcheck.daemon.livenessCheck" . }}
{{- end -}}

{{/*
snark-coordinator readiness settings
*/}}
{{- define "healthcheck.snarkCoordinator.readinessCheck" -}}
{{- include "healthcheck.daemon.readinessCheck" . }}
{{- end -}}

{{/*
ALL snark-coordinator healthchecks
*/}}
{{- define "healthcheck.snarkCoordinator.allChecks" }}
{{- include "healthcheck.snarkCoordinator.livenessCheck" . }}
{{- include "healthcheck.snarkCoordinator.readinessCheck" . }}
{{- end }}
