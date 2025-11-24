#!/bin/bash

CODENAME=$1

find _build -type f -name "*.exe" | while read -r entry; do
  # Transform entry: add 'mina' at beginning and convert _ to -
  new_entry="mina-${entry//_/-}"
  ./buildkite/scripts/cache/manager.sh write "$new_entry" "apps/${CODENAME}/"
done
