#!/bin/bash

# Buildkite test script for convert-daemon-debian-to-hf.sh
# This script sets up the Buildkite environment and then calls the local conversion script

set -eoux pipefail

NETWORK_NAME="devnet"

echo ""
echo "=== Convert Debian to Hardfork Test (Buildkite) ==="
echo "Network: $NETWORK_NAME"
echo ""


# Step 0: Get pre-requisites
echo "=== Step 0: Ensuring pre-requisites are met ==="

buildkite/scripts/debian/update.sh --verbose

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-${NETWORK_NAME}" 1


# Step 1: Get test debian package from cache
echo ""
echo "=== Step 1: Downloading test debian package from cache ==="
./buildkite/scripts/cache/manager.sh read --root test_data mina-daemon-test-package.deb .




INPUT_DEB="./mina-daemon-test-package.deb"

if [[ ! -f "$INPUT_DEB" ]]; then
    echo "ERROR: Test debian package not found at $INPUT_DEB" >&2
    exit 1
fi

echo "✓ Test debian package downloaded: $INPUT_DEB"
echo "Package size: $(du -h "$INPUT_DEB" | cut -f1)"

# Step 2: Run the local conversion script
echo ""
echo "=== Step 2: Running local conversion script ==="

if [[ ! -f scripts/hardfork/release/tests/convert-debian-to-hf-local.sh ]]; then
    echo "ERROR: Local conversion script not found at scripts/hardfork/release/tests/convert-debian-to-hf-local.sh" >&2
    exit 1
fi

# Run the local script
./scripts/hardfork/release/tests/convert-debian-to-hf-local.sh \
    --deb-file "$INPUT_DEB" \
    --network "$NETWORK_NAME" \
    --output-dir "." \
    --keep-temp

echo ""
echo "=== ✅ All tests passed! ==="
