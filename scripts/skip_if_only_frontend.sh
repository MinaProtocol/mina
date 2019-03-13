#!/bin/bash

set -e

# aka if there exist things that don't start with `frontend/` then
if git diff HEAD..$(git merge-base origin/master HEAD) --name-only | grep -E -q -v '^frontend'; then
  exec "$@"
fi

