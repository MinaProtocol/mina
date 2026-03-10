#!/usr/bin/env bash
set -eoux pipefail


# Ensure script is run from the root of the project
if [ ! -f "scripts/export-git-env-vars.sh" ]; then
  echo "❌ Please run this script from the root directory of the Mina repository."
  exit 1
fi

# shellcheck disable=SC1091
source ./scripts/export-git-env-vars.sh

# Default path to executables; can be overridden by environment variables
# This is to alow to use prebuilt executable rather than building them from source
RUNTIME_GENESIS_LEDGER=${RUNTIME_GENESIS_LEDGER:-_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe}
LOGPROC=${LOGPROC:-_build/default/src/app/logproc/logproc.exe}

# Path to the generated runtime config JSON; can be overridden by environment variable
RUNTIME_CONFIG_JSON=${RUNTIME_CONFIG_JSON:-$PWD/new_config.json}

LEDGER_TARBALLS=${LEDGER_TARBALLS:-"$(echo $PWD/hardfork_ledgers/*.tar.gz)"}

DEFAULT_LEDGER_TARBALLS_DIR=${DEFAULT_LEDGER_TARBALLS_DIR:-"$PWD/hardfork_ledgers"}


build_packages() {
  if [ "${NETWORK_NAME}" = "mainnet" ]; then
    export MINA_BUILD_MAINNET=1
  fi

  export BYPASS_OPAM_SWITCH_UPDATE=1

  make build
  make build-daemon-utils
  make build-devnet-sigs
  make build-archive
  make build-archive-utils
  make build-test-utils
}


PWD=$(pwd)

if [ -z "${CONFIG_JSON_GZ_URL+x}" ] || [ -z "${NETWORK_NAME+x}" ] || [ -z "${MINA_DEB_CODENAME+x}" ] || [ -z "${DUNE_PROFILE+x}" ]; then
    echo "❌ Error: Required environment variables not provided:"
    [ -z "${CONFIG_JSON_GZ_URL+x}" ] && echo "  - CONFIG_JSON_GZ_URL: URL to download the network configuration JSON file 🌐"
    [ -z "${NETWORK_NAME+x}" ] && echo "  - NETWORK_NAME: Name of the network to create hardfork package for 🔗"
    [ -z "${MINA_DEB_CODENAME+x}" ] && echo "  - MINA_DEB_CODENAME: Debian codename for package building 📦"
    [ -z "${DUNE_PROFILE+x}" ] && echo "  - DUNE_PROFILE: Dune profile to use for building 🔧"
    exit 1
fi

echo "--- Starting hardfork package generation for network: ${NETWORK_NAME} with Debian codename: ${MINA_DEB_CODENAME}"

build_packages

echo "--- Generating runtime config and ledger tarballs"
./scripts/hardfork/release/generate-fork-config-with-ledger-tarballs.sh \
    --network "$NETWORK_NAME" \
    --config-url "$CONFIG_JSON_GZ_URL" \
    --runtime-ledger "$RUNTIME_GENESIS_LEDGER" \
    --logproc "$LOGPROC" \
    --output-dir "$DEFAULT_LEDGER_TARBALLS_DIR"

echo "--- Uploading generated ledger tarballs to aws"
INPUT_FOLDER="$DEFAULT_LEDGER_TARBALLS_DIR" ./scripts/hardfork/release/upload-ledger-tarballs.sh

echo "--- Build hardfork package for Debian ${MINA_DEB_CODENAME}"
RUNTIME_CONFIG_JSON=$RUNTIME_CONFIG_JSON LEDGER_TARBALLS="$LEDGER_TARBALLS" ./scripts/debian/build.sh "$@"