{{/* Calculates the number of snarker nodes (coordinators for Mina coordinator, snarker nodes for HTTP coordinator) */}}
{{- define "snarkerNodeCount" }}
{{- if .httpCoordinatedSnarkersConfig.count }}
{{ .httpCoordinatedSnarkersConfig.count }}
{{ else }}
{{ .minaSnarkCoordinatorsConfig | len }}
{{- end }}
