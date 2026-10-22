#!/bin/bash

CODENAME=$1

for entry in _build/*.deb; do
  buildkite-cache-manager write "$entry" debians/${CODENAME}/
done 
