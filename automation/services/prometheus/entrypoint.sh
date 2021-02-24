#!/bin/bash
set -x 

j2 prometheus.j2 > /etc/prometheus/prometheus.yml

exec dumb-init /usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.console.templates=/etc/prometheus/consoles