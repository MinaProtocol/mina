### Mina node selector TEMPLATES ###

{{/*
Node selector: preemptible node affinity
*/}}
{{- define "nodeSelector.preemptible" }}
{{- if .nodeSelector.preemptible }}
nodeSelector:
  cloud.google.com/gke-preemptible: "true"
{{- else }}
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: "cloud.google.com/gke-preemptible"
          operator: Exists
      topologyKey: failure-domain.beta.kubernetes.io/region
{{- end }}
{{- end }}

{{/*
Node selector: custom affinity mapping
*/}}
{{- define "nodeSelector.customMapping" }}
{{- if . }}
nodeSelector:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end }}
