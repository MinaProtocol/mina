#!/bin/bash

CODENAME=$1

for entry in _build/*.deb; do
  ./buildkite/scripts/toolkit.sh buildkite-cache-manager write "$entry" debians/${CODENAME}/
done 
