#!/bin/bash
# Run one test_executive test on the native engine: mina and its libp2p helper
# run as host processes, no docker. Binaries come bare from the apps cache.
#
# Usage: run-test-executive-native.sh <test-name>
#
# MINA_PROFILE=lightnet keeps the network inside one agent: no proofs, so the
# daemons stay small. A full devnet network does not fit (see docs/tests.md).

set -eo pipefail

TEST_NAME="$1"
if [[ -z "$TEST_NAME" ]]; then
  echo "Usage: $0 <test-name>" >&2
  exit 1
fi

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

# The daemon finds the helper as coda-libp2p_helper on PATH, like the deb.
./buildkite/scripts/apps/restore_binary.sh
./buildkite/scripts/apps/restore_app.sh libp2p_helper coda-libp2p_helper
./buildkite/scripts/apps/restore_app.sh test_executive.exe mina-test-executive
./buildkite/scripts/apps/restore_app.sh logproc.exe mina-logproc

export MINA_PROFILE=lightnet

mina-test-executive native "$TEST_NAME" \
  --mina-image "$(command -v mina)" \
  | tee "$TEST_NAME.native.test.log" \
  | mina-logproc -i inline -f '!(.level in ["Debug", "Spam"])'
