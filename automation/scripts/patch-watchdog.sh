#!/bin/bash


IMAGE="gcr.io/o1labs-192920/watchdog:0.4.5"


read -r -d '' PATCH << SPEC
spec:
  template:
    spec:
      containers:
        - name: watchdog
          image: $IMAGE
SPEC

echo -e "$PATCH"

kubectl patch deploy/watchdog -p "$PATCH"

# ====================================


read -r -d '' PATCH << SPEC
spec:
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: watchdog
              image: $IMAGE
SPEC

echo -e "$PATCH"

kubectl patch cronjobs/watchdog-make-reports -p "$PATCH"

