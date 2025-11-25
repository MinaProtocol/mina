#!/bin/bash

CODENAME=$1

find _build -type f -name "*.exe" | while read -r entry; do
  # Exclude files ending with ppx.exe
  if [[ "$entry" == *ppx.exe ]]; then
    continue
  fi

    # Get stem from filename (remove path and extension)
  filename=$(basename "$entry")
  stem="${filename%.exe}"
  # Transform stem: add 'mina' at beginning and convert _ to -
  new_entry="mina-${stem//_/-}"
  ./buildkite/scripts/cache/manager.sh write "$new_entry" "apps/${CODENAME}/"
done
