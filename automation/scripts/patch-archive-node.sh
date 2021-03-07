#!/bin/bash


IMAGE="codaprotocol/coda-archive:1.0.2-hotfix-archive-node-metrics-79e5e7c"


read -r -d '' PATCH << SPEC
spec:
  template:
    spec:
      containers:
        - name: archive
          image: $IMAGE
          args:
          - coda-archive
          - run
          - -postgres-uri
          - postgres://postgres:foobar@archive-1-postgresql:5432/archive
          - -config-file
          - /config/daemon.json
          - -server-port
          - "3086"
          - -metrics-port
          - "8081"
SPEC

echo -e "$PATCH"

kubectl patch deploy/archive-1 -p "$PATCH"
