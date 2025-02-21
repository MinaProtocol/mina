#!/bin/bash

CODENAME=$1

for entry in _build/*.deb; do
  ./buildkite/scripts/cache.sh write "$entry" debians/${CODENAME}
done 
