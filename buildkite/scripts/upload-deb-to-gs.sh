#!/bin/bash

CODENAME=$1
GS_DO_NOT_OVERRIDE=1

echo "--- Copy debians to gs"
for entry in _build/*.deb; do
  source ./buildkite/scripts/cache-artifact.sh $entry ${CODENAME}/$entry 
done 
