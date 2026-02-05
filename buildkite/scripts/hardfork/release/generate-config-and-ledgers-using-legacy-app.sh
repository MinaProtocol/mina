#!/bin/bash

set -eo pipefail

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --network)
      network="$2"
      shift 2
      ;;
    --version)
      version="$2"
      shift 2
      ;;
    --codename)
      codename="$2"
      shift 2
      ;;
    --config-json-gz-url)
      config_json_gz_url="$2"
      shift 2
      ;;
    --cached-buildkite-build-id)
      cached_buildkite_build_id="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

./scripts/hardfork/release/generate-fork-config-with-ledger-tarballs-using-legacy-app.sh \
  --network "${network}" \
  --version "${version:-3.2.0-f77c8c9}" \
  --codename "${codename}" \
  --config-json-gz-url "${config_json_gz_url}" \
  ${cached_buildkite_build_id:+--cached-buildkite-build-id "${cached_buildkite_build_id}"}