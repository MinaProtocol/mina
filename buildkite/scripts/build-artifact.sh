#!/bin/bash

set -eo pipefail

([ -z ${DUNE_PROFILE+x} ]) && echo "required env vars were not provided" && exit 1

source ~/.profile

MINA_COMMIT_SHA1=$(git rev-parse HEAD)

# TODO: Stop building lib_p2p multiple times by pulling from buildkite-agent artifacts or docker or somewhere
echo "--- Build libp2p_helper TODO: use the previously uploaded build artifact"
make -C src/app/libp2p_helper

MAINNET_TARGETS=""
[[ ${MINA_BUILD_MAINNET} ]] && MAINNET_TARGETS="src/app/cli/src/mina_mainnet_signatures.exe src/app/rosetta/rosetta_mainnet_signatures.exe src/app/rosetta/ocaml-signer/signer_mainnet_signatures.exe"

echo "--- Build all major tagets required for packaging"
echo "Building from Commit SHA: ${MINA_COMMIT_SHA1}"
echo "Rust Version: $(rustc --version)"
dune build "--profile=${DUNE_PROFILE}" \
  ${MAINNET_TARGETS} \
  src/app/logproc/logproc.exe \
  src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
  src/app/kvdb_tool/kvdb_tool.exe \
  src/app/generate_keypair/generate_keypair.exe \
  src/app/validate_keypair/validate_keypair.exe \
  src/app/cli/src/mina_testnet_signatures.exe \
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
  src/app/rosetta/ocaml-signer/signer_testnet_signatures.exe \
  src/app/test_executive/test_executive.exe  \
  src/test/command_line_tests/command_line_tests.exe # 2>&1 | tee /tmp/buildocaml.log
