### Block Producer healthcheck TEMPLATES ###

{{/*
block-producer startup probe settings
*/}}
{{- define "healthcheck.blockProducer.startupProbe" -}}
{{ include "healthcheck.daemon.startupProbe" . }}
{{- end -}}

{{/*
block-producer liveness settings
*/}}
{{- define "healthcheck.blockProducer.livenessCheck" -}}
{{ include "healthcheck.daemon.livenessCheck" . }}
{{- end -}}

{{/*
block-producer readiness settings
*/}}
{{- define "healthcheck.blockProducer.readinessCheck" -}}
{{ include "healthcheck.daemon.readinessCheck" . }}
{{- end -}}

{{/*
ALL block-producer healthchecks
*/}}
{{- define "healthcheck.blockProducer.healthChecks" -}}
{{ template "healthcheck.blockProducer.startupProbe" . }}
{{ template "healthcheck.blockProducer.livenessCheck" . }}
{{ template "healthcheck.blockProducer.readinessCheck" . }}
{{- end -}}

### User Agent Healthchecks ###

{{/*
user-agent startup probe settings
*/}}
{{- define "healthcheck.userAgent.startupProbe" -}}
{{ include "healthcheck.daemon.startupProbe" . }}
{{- end -}}

{{/*
user-agent liveness check settings
*/}}
{{- define "healthcheck.userAgent.livenessCheck" -}}
livenessProbe:
  tcpSocket:
    port: metrics
{{ include "healthcheck.common.settings" . | indent 2 }}
{{- end -}}

{{/*
block-producer readiness check settings
*/}}
{{- define "healthcheck.userAgent.readinessCheck" -}}
readinessProbe:
  exec:
    command: "<curl localhost:8000/metrics | check-count-against-graphql>"
{{ include "healthcheck.common.settings" . | indent 2 }}
{{- end -}}

{{/*
ALL user-agent healthchecks
*/}}
{{- define "healthcheck.userAgent.healthChecks" -}}
{{ template "healthcheck.userAgent.startupProbe" . }}
{{ template "healthcheck.userAgent.livenessCheck" . }}
{{ template "healthcheck.userAgent.readinessCheck" . }}
{{- end -}}

### Bot Healthchecks ###

{{/*
Mina testnet bot startup probe settings
*/}}
{{- define "healthcheck.bots.startupProbe" -}}
{{ include "healthcheck.daemon.startupProbe" . }}
{{- end -}}

{{/*
Mina testnet bot liveness check settings
*/}}
{{- define "healthcheck.bots.livenessCheck" -}}
livenessProbe:
  tcpSocket:
    port: graphql
{{ include "healthcheck.common.settings" . | indent 2 }}
{{- end -}}

{{/*
Mina testnet bot readiness check settings
*/}}
{{- define "healthcheck.bots.readinessCheck" -}}
readinessProbe:
  exec:
    command: "<verify-echo-faucet-functional>"
{{ include "healthcheck.common.settings" . | indent 2 }}
{{- end -}}

{{/*
ALL bots healthchecks
*/}}
{{- define "healthcheck.bots.healthChecks" -}}
{{ template "healthcheck.bots.startupProbe" . }}
{{ template "healthcheck.bots.livenessCheck" . }}
{{ template "healthcheck.bots.readinessCheck" . }}
{{- end -}}
