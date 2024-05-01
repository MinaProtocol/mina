#!/bin/bash

set -eo pipefail

([ -z ${CONFIG_JSON_GZ_URL+x} ]) && echo "required env vars were not provided" && exit 1

echo "--- Download and extract previous network config"
curl -o config.json.gz $CONFIG_JSON_GZ_URL
gunzip config.json.gz

# Patch against a bug in 1.4 which is fixed by PR #15462
mv config.json config_orig.json
jq 'del(.ledger.num_accounts) | del(.ledger.name)' config_orig.json > config.json 

echo "--- Migrate accounts to new network format"
# TODO: At this stage, we need to migrate the json accounts into the new network's format.
#       For now, this is hard-coded to the mainnet -> berkeley migration, but we need to select
#       a migration to perform in the future.
# NB: we use sed here instead of jq, because jq is extremely slow at processing this file
sed -i -e 's/"set_verification_key": "signature"/"set_verification_key": {"auth": "signature", "txn_version": "2"}/' config.json

echo "--- Generate hardfork ledger tarballs"
mkdir hardfork_ledgers
mina-create-genesis --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json | tee runtime_genesis_ledger.log | mina-logproc

echo "--- Create hardfork config"
FORK_CONFIG_JSON=config.json LEDGER_HASHES_JSON=hardfork_ledger_hashes.json mina-hf-create-runtime-config > new_config.json

echo "--- New genesis config"
cat new_config.json
