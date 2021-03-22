#!/bin/bash


IMAGE="gcr.io/o1labs-192920/coda-archive:1.1.2-0975867"


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
          - -metrics-port
          - "10002"
          - -postgres-uri
          - postgres://postgres:foobar@archive-1-postgresql:5432/archive
          - -config-file
          - /config/daemon.json
          - -server-port
          - "3086"
SPEC

echo -e "$PATCH"

kubectl patch deploy/archive-1 -p "$PATCH"
