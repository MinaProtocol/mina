### Block Producer healthcheck TEMPLATES ###

{{/*
block-producer startup probe settings
*/}}
{{- define "healthcheck.blockProducer.startupProbe" }}
{{- include "healthcheck.daemon.startupProbe" . }}
{{- end }}

{{/*
block-producer liveness settings
*/}}
{{- define "healthcheck.blockProducer.livenessCheck" }}
{{- include "healthcheck.daemon.livenessCheck" . }}
{{- end }}

{{/*
block-producer readiness settings
*/}}
{{- define "healthcheck.blockProducer.readinessCheck" }}
{{- include "healthcheck.daemon.readinessCheck" . }}
{{- end }}

{{/*
ALL block-producer healthchecks - TODO: readd startupProbes once clusters k8s have been updated to 1.16
*/}}
{{- define "healthcheck.blockProducer.allChecks" }}
{{- include "healthcheck.blockProducer.livenessCheck" . }}
{{- include "healthcheck.blockProducer.readinessCheck" . }}
{{- end }}

### User Agent Healthchecks ###

{{/*
user-agent startup probe settings
*/}}
{{- define "healthcheck.userAgent.startupProbe" }}
{{- include "healthcheck.daemon.startupProbe" . }}
{{- end }}

{{/*
user-agent liveness check settings
*/}}
{{- define "healthcheck.userAgent.livenessCheck" }}
livenessProbe:
  tcpSocket:
    port: metrics-port
{{- include "healthcheck.common.settings" . | indent 2 }}
{{- end }}

{{/*
user-agent readiness check settings
*/}}
{{- define "healthcheck.userAgent.readinessCheck" }}
readinessProbe:
  exec:
    command: ["curl localhost:8000/metrics"]
{{- include "healthcheck.common.settings" . | indent 2 }}
{{- end }}

{{/*
ALL user-agent healthchecks - TODO: readd startupProbes once clusters k8s have been updated to 1.16
*/}}
{{- define "healthcheck.userAgent.allChecks" }}
{{- include "healthcheck.userAgent.livenessCheck" . }}
{{- include "healthcheck.userAgent.readinessCheck" . }}
{{- end }}

### Bot Healthchecks ###

{{/*
Mina testnet bot startup probe settings
*/}}
{{- define "healthcheck.bots.startupProbe" }}
{{- include "healthcheck.daemon.startupProbe" . }}
{{- end }}

{{/*
Mina testnet bot liveness check settings
*/}}
{{- define "healthcheck.bots.livenessCheck" }}
livenessProbe:
  tcpSocket:
    port: graphql-port
{{- include "healthcheck.common.settings" . | indent 2 }}
{{- end }}

{{/*
Mina testnet bot readiness check settings
*/}}
{{- define "healthcheck.bots.readinessCheck" }}
readinessProbe:
  exec:
    command: ["<verify-echo-faucet-functional>"]
{{- include "healthcheck.common.settings" . | indent 2 }}
{{- end }}

{{/*
ALL bots healthchecks - TODO: readd startupProbes once clusters k8s have been updated to 1.16
*/}}
{{- define "healthcheck.bots.allChecks" }}
{{- include "healthcheck.bots.livenessCheck" . }}
{{- include "healthcheck.bots.readinessCheck" . }}
{{- end }}
