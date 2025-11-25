#!/usr/bin/env bash

set -eoux pipefail


# shellcheck disable=SC1091
source ./scripts/export-git-env-vars.sh


# Default path to executables; can be overridden by environment variables
# This is to alow to use prebuilt executable rather than building them from source
RUNTIME_GENESIS_LEDGER=${RUNTIME_GENESIS_LEDGER:-_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe}
LOGPROC=${LOGPROC:-_build/default/src/app/logproc/logproc.exe}

# Optional: reuse build artifacts from Buildkite builds instead of building from source
SKIP_APPS_BUILD=${SKIP_APPS_BUILD:-}

# Optional: skip building the debian packages but inject the runtime config and ledger tarballs instead
SKIP_DEBIAN_PACKAGE_BUILD=${SKIP_DEBIAN_PACKAGE_BUILD:-}

# Optional: skip generation of ledger tarballs
SKIP_TARBALLS_GENERATION=${SKIP_TARBALLS_GENERATION:-}

# Optional: skip upload of generated tarballs
SKIP_TARBALL_UPLOAD=${SKIP_TARBALL_UPLOAD:-}


# Path to the generated runtime config JSON; can be overridden by environment variable
RUNTIME_CONFIG_JSON=${RUNTIME_CONFIG_JSON:-$PWD/new_config.json}

LEDGER_TARBALLS=${LEDGER_TARBALLS:-"$(echo $PWD/hardfork_ledgers/*.tar.gz)"}


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

if [ -z "$SKIP_APPS_BUILD" ]; then
  echo "--- Skipping build of executables; using prebuilt ones"
else
  echo "--- Building necessary executables from source"
  build_packages
fi

if [ -z "$SKIP_TARBALLS_GENERATION" ]; then
  echo "--- Generating runtime config and ledger tarballs"
  ./scripts/hardfork/generate-tarballs.sh \
    --network "$NETWORK_NAME" \
    --config-url "$CONFIG_JSON_GZ_URL" \
    --runtime-ledger "$RUNTIME_GENESIS_LEDGER" \
    --logproc "$LOGPROC"
else
  echo "--- Skipping generation of runtime config and ledger tarballs"
fi

if [ -z "$SKIP_TARBALL_UPLOAD" ]; then
  echo "--- Uploading generated ledger tarballs to aws"
  ./scripts/hardfork/upload-ledger-tarballs.sh \
    --network "$NETWORK_NAME" \
    --logproc "$LOGPROC"
else
  echo "--- Skipping upload of generated ledger tarballs"
fi

echo "--- Build hardfork package for Debian ${MINA_DEB_CODENAME}"
if [ -n "$SKIP_DEBIAN_PACKAGE_BUILD" ]; then
  echo "--- Skipping debian package build; injecting runtime config and ledger tarballs into existing packages"
  ./scripts/debian/replace-entry.sh mina-daemon.deb /var/lib/coda/config_*.json "$RUNTIME_CONFIG_JSON"
  ./scripts/debian/insert-entries.sh mina-daemon.deb /var/lib/coda/ "$LEDGER_TARBALLS"
else
  echo "--- Building debian packages from source"
  RUNTIME_CONFIG_JSON=$RUNTIME_CONFIG_JSON LEDGER_TARBALLS="$LEDGER_TARBALLS" ./scripts/debian/build.sh "$@"
fi