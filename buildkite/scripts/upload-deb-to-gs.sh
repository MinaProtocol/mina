#!/bin/bash

CODENAME=$1

echo "--- Copy debians to gs"
for entry in _build/*.deb; do
  source ./buildkite/scripts/cache-artifact.sh $entry ${CODENAME}/debs
done 
