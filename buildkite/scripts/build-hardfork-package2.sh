#!/bin/bash
set -eo pipefail

# TODO: refactor this script into build-hardfork-package.sh (or vice-versa)

([ -z "$CONFIG_JSON_GZ_URL" ] || [ -z "$DUNE_PROFILE" ]) && echo "required env vars were not provided" && exit 1

source ~/.profile

curl -o config.json.gz $CONFIG_JSON_GZ_URL
gunzip config.json.gz

# TODO: At this stage, we need to migrate the json accounts into the new network's format.
#       For now, this is hard-coded to the mainnet -> berkeley migration, but we need to select
#       a migration to perform in the future.

# NB: we use sed here instead of jq, because jq is extremely slow at processing this file
sed -i -e 's/"set_verification_key": "signature"/"set_verification_key": {"auth": "signature", "txn_version": "1"}/' config.json

dune build --profile="$DUNE_PROFILE" src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe src/app/logproc/logproc.exe

mkdir hardfork_ledgers
_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json | tee runtime_genesis_ledger.log | _build/default/src/app/logproc/logproc.exe

FORK_CONFIG_JSON=config.json LEDGER_HASHES_JSON=hardfork_ledger_hashes.json scripts/hardfork/create_runtime_config.sh > new_config.json

MINA_BUILD_MAINNET=1 RUNTIME_CONFIG_JSON=new_config.json LEDGER_TARBALLS="$(echo hardfork_ledgers/*.tar.gz)" exec ./buildkite/scripts/build-hardfork-package.sh
