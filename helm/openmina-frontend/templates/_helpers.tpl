{{- define "frontend-app-config-entry" -}}
        {{ if not .first }}, {{ end }}
        {
          "graphql": "/{{ .name }}",
          "tracing-graphql": "/{{ .name }}/internal-trace",
          {{ if .debugger }}
          "debugger": "/{{ .name }}/{{ .debugger }}",
          {{ end }}
          "features": [
            "dashboard",
            {{ if .debugger }}
            "network",
            {{ end }}
            "benchmarks",
            "explorer",
            "tracing",
            "resources",
            "logs"
          ],
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
    resolver {{ .resolver | default "coredns.kube-system.svc.cluster.local" }};
    server {
        listen 80;
        location / {
           root /usr/share/nginx/html;
           try_files $uri $uri/ /index.html;
           index index.html index.htm;
           error_page 404 /usr/share/nginx/html/index.html;
        }
        location /snarker-http-coordinator {
           set $upstream snarker-http-coordinator;
           rewrite ^/snarker-http-coordinator($|/.*) $1 break;
           proxy_pass http://$upstream;
        }
        {{ range $node := .nodes }}
        location /{{ $node.name }}/graphql {
           set $upstream {{ $node.name }}-graphql.{{ $node.namespace }}.svc.cluster.local;
           proxy_pass http://$upstream/graphql;
        }
        location /{{ $node.name }}/internal-trace/graphql {
           set $upstream {{ $node.name }}-internal-trace-graphql.{{ $node.namespace }}.svc.cluster.local;
           proxy_pass http://$upstream/graphql;
        }
        location /{{ $node.name }}/resources {
           set $upstream {{ $node.name }}-resources.{{ $node.namespace }}.svc.cluster.local;
           rewrite ^/{{ $node.name }}/resources(.*) /$1 break;
           proxy_pass http://$upstream/resources;
        }
        location /{{ $node.name }}/bpf-debugger {
           set $upstream {{ $node.name }}-bpf-debugger.{{ $node.namespace }}.svc.cluster.local;
           rewrite ^/{{ $node.name }}/bpf-debugger/(.*) /$1 break;
           proxy_pass http://$upstream;
        }
        location /{{ $node.name }}/ptrace-debugger {
           set $upstream {{ $node.name }}-ptrace-debugger.{{ $node.namespace }}.svc.cluster.local;
           proxy_pass http://$upstream;
        }
        location /{{ $node.name }}/logs {
           rewrite_log on;
           set $upstream {{ $node.name }}-logs.{{ $node.namespace }}.svc.cluster.local;
           rewrite ^/{{ $node.name }}/logs/(.*) /$1 break;
           proxy_pass http://$upstream;
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
