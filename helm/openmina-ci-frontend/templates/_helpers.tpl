{{/*
Nginx configuration
*/}}
{{- define "ci-frontend-nginx-conf" -}}
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    resolver coredns.kube-system.svc.cluster.local;
    server {
	    listen 80;

        location / {
           root /usr/share/nginx/html;
           try_files $uri $uri/ /index.html;
           index index.html index.htm;
           error_page 404 /usr/share/nginx/html/index.html;
        }
        {{ $namespace := .namespace }}
        location /aggregator {
           set $upstream aggregator-service.{{ $namespace }}.svc.cluster.local;
           rewrite ^/aggregator($|/.*) $1 break;
           proxy_pass http://$upstream;
        }
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