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

echo "--- Build libp2p_helper"
make -C src/app/libp2p_helper

MAINNET_TARGETS=""
[[ ${MINA_BUILD_MAINNET} ]] && MAINNET_TARGETS="src/app/cli/src/mina_mainnet_signatures.exe src/app/rosetta/rosetta_mainnet_signatures.exe src/app/rosetta/ocaml-signer/signer_mainnet_signatures.exe"

echo "--- Build all major tagets required for packaging"
echo "Building from Commit SHA: ${MINA_COMMIT_SHA1}"
echo "Rust Version: $(rustc --version)"
dune build "--profile=${DUNE_PROFILE}" \
  src/app/logproc/logproc.exe \
  src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
  src/app/generate_keypair/generate_keypair.exe \
  src/app/validate_keypair/validate_keypair.exe \
  src/app/cli/src/mina_testnet_signatures.exe \
  src/app/cli/src/mina_mainnet_signatures.exe \
  src/app/archive/archive.exe \
  src/app/replayer/replayer.exe \
  src/app/extract_blocks/extract_blocks.exe \
  src/app/archive_blocks/archive_blocks.exe \
  src/app/berkeley_migration/berkeley_migration.exe \
  src/app/last_vrf_output_to_b64/last_vrf_output_to_b64.exe \
  src/app/receipt_chain_hash_to_b58/receipt_chain_hash_to_b58.exe \
  src/app/batch_txn_tool/batch_txn_tool.exe \
  src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
  src/app/swap_bad_balances/swap_bad_balances.exe \
  src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
  src/app/rosetta/rosetta_testnet_signatures.exe \
  src/app/rosetta/rosetta_mainnet_signatures.exe \
  src/app/rosetta/ocaml-signer/signer_testnet_signatures.exe \
  src/app/rosetta/ocaml-signer/signer_mainnet_signatures.exe \
  src/app/test_executive/test_executive.exe  \
  src/test/command_line_tests/command_line_tests.exe # 2>&1 | tee /tmp/buildocaml.log

echo "--- Generate hardfork ledger tarballs"
mkdir hardfork_ledgers
_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json | tee runtime_genesis_ledger.log | _build/default/src/app/logproc/logproc.exe

echo "--- Create hardfork config"
FORK_CONFIG_JSON=config.json LEDGER_HASHES_JSON=hardfork_ledger_hashes.json scripts/hardfork/create_runtime_config.sh > new_config.json

echo "--- Build hardfork package for Debian ${MINA_DEB_CODENAME}"
MINA_BUILD_MAINNET=1 RUNTIME_CONFIG_JSON=new_config.json LEDGER_TARBALLS="$(echo hardfork_ledgers/*.tar.gz)" ./scripts/create_hardfork_deb.sh
MINA_BUILD_MAINNET=1 RUNTIME_CONFIG_JSON=new_config.json LEDGER_TARBALLS="$(echo hardfork_ledgers/*.tar.gz)" ./scripts/archive/build-release-archives.sh
mkdir -p /tmp/artifacts
cp _build/mina*.deb /tmp/artifacts/.

echo "--- Upload debs to amazon s3 repo"
make publish_debs

echo "--- Git diff after build is complete:"
git diff --exit-code -- .
