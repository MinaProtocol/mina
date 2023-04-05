#!/bin/bash

set -eo pipefail

eval $(opam config env)
export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

MINA_COMMIT_SHA1=$(git rev-parse HEAD)

# TODO: Stop building lib_p2p multiple times by pulling from buildkite-agent artifacts or docker or somewhere
echo "--- Build libp2p_helper TODO: use the previously uploaded build artifact"
make -C src/app/libp2p_helper

MAINNET_TARGETS=""
[[ ${MINA_BUILD_MAINNET} ]] && MAINNET_TARGETS="src/app/cli/src/mina_mainnet_signatures.exe src/app/rosetta/rosetta_mainnet_signatures.exe "

echo "--- Build all major tagets required for packaging"
echo "Building from Commit SHA: ${MINA_COMMIT_SHA1}"
echo "Rust Version: $(rustc --version)"
opam pin src/external/async_kernel
dune build "--profile=${DUNE_PROFILE}" \
  src/app/logproc/logproc.exe \
  src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
  src/app/generate_keypair/generate_keypair.exe \
  src/app/validate_keypair/validate_keypair.exe \
  src/app/cli/src/mina_testnet_signatures.exe \
  src/app/archive/archive.exe \
  src/app/replayer/replayer.exe \
  src/app/extract_blocks/extract_blocks.exe \
  src/app/archive_blocks/archive_blocks.exe \
  src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
  src/app/swap_bad_balances/swap_bad_balances.exe \
  src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
  src/app/rosetta/rosetta_testnet_signatures.exe \
  src/app/test_executive/test_executive.exe # 2>&1 | tee /tmp/buildocaml.log

echo "--- Bundle all packages for Debian ${MINA_DEB_CODENAME}"
echo " Includes mina daemon, archive-node, rosetta, generate keypair for berkeley"
[[ ${MINA_BUILD_MAINNET} ]] && echo " MINA_BUILD_MAINNET is true so this includes the mainnet and devnet packages for mina-daemon as well"
make deb

make test_executive_deb

echo "--- Upload debs to amazon s3 repo"
make publish_debs

echo "--- Git diff after build is complete:"
git diff --exit-code
