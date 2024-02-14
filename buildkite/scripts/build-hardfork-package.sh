#!/bin/bash

set -eo pipefail

([ -z "$DUNE_PROFILE" ] || [ -z "$CONFIG_JSON_GZ_URL" ] || [ -z "$MINA_DEB_CODENAME" ]) && echo "required env vars were not provided" && exit 1

source ~/.profile

MINA_COMMIT_SHA1=$(git rev-parse HEAD)

echo "--- Download and extract previous network config"
curl -o config.json.gz $CONFIG_JSON_GZ_URL
gunzip config.json.gz

echo "--- Migrate accounts to new network format"
# TODO: At this stage, we need to migrate the json accounts into the new network's format.
#       For now, this is hard-coded to the mainnet -> berkeley migration, but we need to select
#       a migration to perform in the future.
# NB: we use sed here instead of jq, because jq is extremely slow at processing this file
sed -i -e 's/"set_verification_key": "signature"/"set_verification_key": {"auth": "signature", "txn_version": "1"}/' config.json

./buildkite/scripts/build-artifacts.sh

echo "--- Generate hardfork ledger tarballs"
mkdir hardfork_ledgers
_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json | tee runtime_genesis_ledger.log | _build/default/src/app/logproc/logproc.exe

echo "--- Create hardfork config"
FORK_CONFIG_JSON=config.json LEDGER_HASHES_JSON=hardfork_ledger_hashes.json scripts/hardfork/create_runtime_config.sh > new_config.json

echo "--- Build hardfork package for Debian ${MINA_DEB_CODENAME}"
MINA_BUILD_MAINNET=1 RUNTIME_CONFIG_JSON=new_config.json LEDGER_TARBALLS="$(echo hardfork_ledgers/*.tar.gz)" ./scripts/create_hardfork_deb.sh
mkdir -p /tmp/artifacts
cp _build/mina*.deb /tmp/artifacts/.

echo "--- Upload debs to amazon s3 repo"
make publish_debs

echo "--- Git diff after build is complete:"
git diff --exit-code -- .
