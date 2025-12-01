#!/usr/bin/env bash

set -e

echo "--- Uploading ledger tarballs to S3"

mkdir -p ./hardfork_ledgers

./buildkite/scripts/cache/manager.sh read hardfork/ledgers/*.tar.gz hardfork_ledgers/

INPUT_FOLDER=./hardfork_ledgers ./scripts/hardfork/upload_ledger_tarballs.sh