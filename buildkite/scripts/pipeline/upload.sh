#!/usr/bin/env bash

set -euo pipefail

input=""
if [[ $# -gt 0 ]]; then
  input="$1"
elif [[ ! -t 0 ]]; then
  input="$(cat)"
else
  echo "Error: expected Dhall input via arg or stdin." >&2
  exit 2
fi

# Generate YAML from Dhall
if ! output=$(dhall-to-yaml --quoted <<< "$input"); then
  echo "Error: dhall-to-yaml failed with exit code $?" >&2
  exit 1
fi

if [[ -z "$output" ]]; then
  echo "Error: dhall-to-yaml produced no output." >&2
  exit 1
fi

# Check for errors in output
if echo "$output" | grep -q "NoResponseDataReceived"; then
  echo "Error: NoResponseDataReceived detected in dhall-to-yaml output." >&2
  exit 1
fi


# Upload to buildkite-agent if no error
buildkite-agent pipeline upload <<< "$output"
