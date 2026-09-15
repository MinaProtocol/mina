#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${DUNE_PROFILE:-}" ]]; then
    dune_profile_val="Some \"$DUNE_PROFILE\""
else
    dune_profile_val="None"
fi

printf 'let dune_profile : string option = %s\n' "$dune_profile_val" > "$1"
