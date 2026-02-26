#!/usr/bin/env bash

# See README.md file for context

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" ; pwd -P )"

cd "$SCRIPTPATH"
CURRENT_SUMMARY="$(nix build mina#mina_coverage --no-link --print-out-paths)/summary"
dune exec "./main.exe" "$CURRENT_SUMMARY" | column -t  -N "Lines added in develop","file","Coverage (%)"
