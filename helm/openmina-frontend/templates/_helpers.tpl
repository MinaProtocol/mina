{{- define "frontend-app-config-entry" -}}
        {{ if not .first }}, {{ end }}
        {
          "graphql": "/{{ .name }}",
          "tracing-graphql": "/{{ .name }}/internal-trace",
          "debugger": "/{{ .name }}/{{ .debugger }}",
          "name": "{{.name}}"
        }
{{- end }}


{{/*
Nginx configuration
*/}}
{{- define "frontend-nginx-conf" -}}
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    server {
        listen 80;
        location / {
           root /usr/share/nginx/html;
           try_files $uri $uri/ /index.html;
           index index.html index.htm;
           error_page 404 /usr/share/nginx/html/index.html;
        }
        {{ if .httpSnarkWorkCoordinator }}
        location /snarker-http-coordinator {
           rewrite ^/snarker-http-coordinator($|/.*) $1 break;
           proxy_pass http://snarker-http-coordinator.{{ .namespace }}.svc.cluster.local;
        }
        {{ end }}
        {{ range $node := .nodes }}
        location /{{ $node.name }}/graphql {
           sub_filter_types *;
           sub_filter '"http://"' '(window.location.protocol == "https:" ? "https://" : "http://")';
           sub_filter '"ws://"' '(window.location.protocol == "https:" ? "wss://" : "ws://")';
           proxy_pass http://{{ $node.name }}-graphql.{{ $node.namespace }}.svc.cluster.local/graphql;
        }
        location /{{ $node.name }}/resources {
           proxy_pass http://{{ $node.name }}-resources.{{ $node.namespace }}.svc.cluster.local/resources;
        }
        location /{{ $node.name }}/logs {
           rewrite_log on;
           rewrite ^/{{ $node.name }}/logs/(.*) /$1 break;
           proxy_pass http://{{ $node.name }}-logs.{{ $node.namespace }}.svc.cluster.local;
        }
        {{ end }}
    }

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    keepalive_timeout  65;
}
{{- end }}

{{/*
Nginx backends configuration
*/}}
{{- define "frontend-nginx-backends" -}}
{{ range $seed := $.Values.seedConfigs }}
{{ include "frontend-nginx-backend-location" }}
{{ end }}
{{- end }}

{{/*
Nginx backend configuration
*/}}
{{- define "frontend-nginx-graphql-location" -}}
        location / {
           root /usr/share/nginx/html;
           try_files $uri $uri/ /index.html;
           index index.html index.htm;
           error_page 404 /usr/share/nginx/html/index.html;
        }
{{- end }}


{{/*
Expand the name of the chart.
*/}}
{{- define "openmina-frontend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openmina-frontend.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openmina-frontend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openmina-frontend.labels" -}}
helm.sh/chart: {{ include "openmina-frontend.chart" . }}
{{ include "openmina-frontend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openmina-frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openmina-frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openmina-frontend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openmina-frontend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
