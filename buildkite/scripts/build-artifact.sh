#!/bin/bash

set -eox pipefail

([ -z ${DUNE_PROFILE+x} ]) && echo "required env vars were not provided" && exit 1

source ~/.profile

MINA_COMMIT_SHA1=$(git rev-parse HEAD)

# Somehow defining DUNE_INSTRUMENT_WITH in docker is not enough to propagate it to dune
# That's why we are converting it to dune argument
if [[ -v DUNE_INSTRUMENT_WITH ]]; then
  INSTRUMENTED_PARAM="--instrument-with $DUNE_INSTRUMENT_WITH"
else 
  INSTRUMENTED_PARAM=""
fi


echo "--- Build libp2p_helper"
make -C src/app/libp2p_helper

MAINNET_TARGETS=""
[[ ${MINA_BUILD_MAINNET} ]] && MAINNET_TARGETS="src/app/cli/src/mina_mainnet_signatures.exe src/app/rosetta/rosetta_mainnet_signatures.exe src/app/rosetta/ocaml-signer/signer_mainnet_signatures.exe"

echo "--- Build all major targets required for packaging"
echo "Building from Commit SHA: ${MINA_COMMIT_SHA1}"
echo "Rust Version: $(rustc --version)"
dune build "--profile=${DUNE_PROFILE}" $INSTRUMENTED_PARAM \
  ${MAINNET_TARGETS} \
  src/app/logproc/logproc.exe \
  src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
  src/app/generate_keypair/generate_keypair.exe \
  src/app/validate_keypair/validate_keypair.exe \
  src/app/cli/src/mina_testnet_signatures.exe \
  src/app/archive/archive.exe \
  src/app/replayer/replayer.exe \
  src/app/extract_blocks/extract_blocks.exe \
  src/app/archive_blocks/archive_blocks.exe \
  src/app/batch_txn_tool/batch_txn_tool.exe \
  src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
  src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
  src/app/rosetta/rosetta_testnet_signatures.exe \
  src/app/rosetta/indexer_test/indexer_test.exe \
  src/app/rosetta/ocaml-signer/signer_testnet_signatures.exe \
  src/app/test_executive/test_executive.exe  \
  src/test/command_line_tests/command_line_tests.exe \
  src/test/archive/patch_archive_test/patch_archive_test.exe
