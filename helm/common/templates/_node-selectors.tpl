### Mina node selector TEMPLATES ###

{{/*
Node selector: preemptible node affinity
*/}}
{{- define "nodeSelector.preemptible" }}
nodeSelector:
    cloud.google.com/gke-preemptible: {{ .nodeSelector.preemptible }}
{{- end }}

{{/*
Node selector: custom affinity mapping
*/}}
{{- define "nodeSelector.customMapping" }}
{{- if . }}
nodeSelector:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end }}
