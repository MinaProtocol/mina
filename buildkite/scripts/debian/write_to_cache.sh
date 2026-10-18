#!/bin/bash

CODENAME=$1

for entry in _build/*.deb; do
  ./buildkite/scripts/cache/manager.sh write-to-dir "$entry" debians/${CODENAME}/
done 
