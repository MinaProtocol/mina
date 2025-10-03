#!/bin/bash
set -euo pipefail


SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
BUILD_DIR=${BUILD_DIR:-"${SCRIPTPATH}/../../_build"}
BUILD_URL=${BUILD_URL:-${BUILDKITE_BUILD_URL:-"local build from '$(hostname)' \
  host"}}
MINA_DEB_CODENAME=${MINA_DEB_CODENAME:-"bullseye"}
MINA_DEB_VERSION=${MINA_DEB_VERSION:-"0.0.0-experimental"}
MINA_DEB_RELEASE=${MINA_DEB_RELEASE:-"unstable"}
ARCHITECTURE=${ARCHITECTURE:-"amd64"}

# Helper script to include when building deb archives.

echo "--- Setting up the environment to build debian packages..."
cd "${BUILD_DIR}" || exit 1


GITHASH=$(git rev-parse --short=7 HEAD)
GITHASH_CONFIG=$(git rev-parse --short=8 --verify HEAD)

SUGGESTED_DEPS="jq, curl, wget"

TEST_EXECUTIVE_DEPS=", mina-logproc, python3, docker-ce "

case "${MINA_DEB_CODENAME}" in
  noble)
    SHARED_DEPS="libssl3t64, libgmp10, libgomp1, tzdata, rocksdb-tools, liblmdb0"
    DAEMON_DEPS=", libffi8, libjemalloc2, libpq-dev, libproc2-0, mina-logproc"
    ARCHIVE_DEPS="libssl3t64, libgomp1, libpq-dev, libjemalloc2"
    ;;
  jammy)
    SHARED_DEPS="libssl3, libgmp10, libgomp1, tzdata, rocksdb-tools, liblmdb0"
    DAEMON_DEPS=", libffi8, libjemalloc2, libpq-dev, libprocps8, mina-logproc"
    ARCHIVE_DEPS="libssl3, libgomp1, libpq-dev, libjemalloc2"
  ;;
  bookworm)
    SHARED_DEPS="libssl3, libgmp10, libgomp1, tzdata, rocksdb-tools, liblmdb0"
    DAEMON_DEPS=", libffi8, libjemalloc2, libpq-dev, libproc2-0, mina-logproc"
    ARCHIVE_DEPS="libssl3, libgomp1, libpq-dev, libjemalloc2"
    ;;
  bullseye|focal)
    SHARED_DEPS="libssl1.1, libgmp10, libgomp1, tzdata, rocksdb-tools, liblmdb0"
    DAEMON_DEPS=", libffi7, libjemalloc2, libpq-dev, libprocps8, mina-logproc"
    ARCHIVE_DEPS="libssl1.1, libgomp1, libpq-dev, libjemalloc2"
    ;;
  *)
    echo "Unknown Debian codename provided: ${MINA_DEB_CODENAME}"; exit 1
    ;;
esac

DUNE_PROFILE="${DUNE_PROFILE}"
DEB_SUFFIX=""

# Add suffix to debian to distinguish different profiles
# (mainnet/devnet/lightnet)
case "${DUNE_PROFILE}" in
  lightnet)
    # use dune profile as suffix but replace underscore to dashes so deb
    # builder won't complain
    _SUFFIX=${DUNE_PROFILE//_/-}
    DEB_SUFFIX="${_SUFFIX}"
    ;;
esac


#Add suffix to debian to distinguish instrumented packages
if [[ -v DUNE_INSTRUMENT_WITH ]]; then
    INSTRUMENTED_SUFFIX=instrumented
    DEB_SUFFIX="${DEB_SUFFIX}-${INSTRUMENTED_SUFFIX}"
fi

BUILDDIR="deb_build"

# Function to ease creation of Debian package control files
create_control_file() {

  echo "------------------------------------------------------------"
  echo "create_control_file inputs:"
  echo "Package Name: ${1}"
  echo "Dependencies: ${2}"
  echo "Description: ${3}"

  # Make sure the directory exists
  mkdir -p "${BUILDDIR}/DEBIAN"

  # Also clean/create the binary directory that all packages need
  rm -rf "${BUILDDIR}/usr/local/bin"
  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Create the control file itself
  cat << EOF > "${BUILDDIR}/DEBIAN/control"
Package: ${1}
Version: ${MINA_DEB_VERSION}
License: Apache-2.0
Origin: MinaProtocol
Label: MinaProtocol
Vendor: O(1)Labs
Codename: ${MINA_DEB_CODENAME}
Suite: ${MINA_DEB_RELEASE}
Architecture: ${ARCHITECTURE}
Maintainer: O(1)Labs <build@o1labs.org>
Installed-Size:
Depends: ${2}
Section: base
Priority: optional
Homepage: https://minaprotocol.com/
Description:
 ${3}
 Built from ${GITHASH} by ${BUILD_URL}
EOF

  echo "------------------------------------------------------------"
  echo "Control File:"
  cat "${BUILDDIR}/DEBIAN/control"

}

# Function to ease package build
build_deb() {

  echo "------------------------------------------------------------"
  echo "build_deb inputs:"
  echo "Package Name: ${1}"

  # echo contents of deb
  echo "------------------------------------------------------------"
  echo "Deb Contents:"
  find "${BUILDDIR}"

  # Build the package
  echo "------------------------------------------------------------"
  # NOTE: the reason for `-Zgzip` is we might be building on newer Ubuntu, e.g.
  # Noble. The default packaging format is `zstd`, but then when we're building
  # Docker image, we're examining those packages in buildkite's agent, where
  # `zstd` might not be available.
  fakeroot dpkg-deb -Zgzip --build "${BUILDDIR}" \
    "${1}"_"${MINA_DEB_VERSION}"_"${ARCHITECTURE}".deb
  echo "build_deb outputs:"
  ls -lh "${1}"_*.deb
  echo "deleting BUILDDIR ${BUILDDIR}"
  rm -rf "${BUILDDIR}"

  echo "--- Built ${1}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb"
}

# Function to DRY copying config files into daemon packages
copy_common_daemon_configs() {

  echo "------------------------------------------------------------"
  echo "copy_common_daemon_configs inputs:"
  echo "Network Name: ${1} (like mainnet, devnet, berkeley)"
  echo "Seed List URL path: ${2} (like seed-lists/berkeley_seeds.txt)"

  # Copy shared binaries
  cp ../src/app/libp2p_helper/result/bin/libp2p_helper \
    "${BUILDDIR}/usr/local/bin/coda-libp2p_helper"
  cp ./default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
    "${BUILDDIR}/usr/local/bin/mina-create-genesis"
  cp ./default/src/app/generate_keypair/generate_keypair.exe \
    "${BUILDDIR}/usr/local/bin/mina-generate-keypair"
  cp ./default/src/app/validate_keypair/validate_keypair.exe \
    "${BUILDDIR}/usr/local/bin/mina-validate-keypair"
  cp ./default/src/lib/snark_worker/standalone/run_snark_worker.exe \
    "${BUILDDIR}/usr/local/bin/mina-standalone-snark-worker"
  cp ./default/src/app/cli/src/mina.exe "${BUILDDIR}/usr/local/bin/mina"

  # Copy over Build Configs
  mkdir -p "${BUILDDIR}/etc/coda/build_config"
  # Use parameter expansion to either return "mainnet.mlh" or "devnet.mlh"
  cp "../src/config/public_network.mlh" \
    "${BUILDDIR}/etc/coda/build_config/BUILD.mlh"
  rsync -Huav ../src/config/* "${BUILDDIR}/etc/coda/build_config/."

  mkdir -p "${BUILDDIR}/var/lib/coda"

  # Include all useful genesis ledgers
  cp ../genesis_ledgers/mainnet.json "${BUILDDIR}/var/lib/coda/mainnet.json"
  cp ../genesis_ledgers/devnet.json "${BUILDDIR}/var/lib/coda/devnet.json"
  cp ../genesis_ledgers/berkeley.json "${BUILDDIR}/var/lib/coda/berkeley.json"
  # Set the default configuration based on Network name ($1)
  cp ../genesis_ledgers/"${1}".json \
    "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"
  cp ../scripts/hardfork/create_runtime_config.sh \
    "${BUILDDIR}/usr/local/bin/mina-hf-create-runtime-config"
  cp ../scripts/hardfork/mina-verify-packaged-fork-config \
    "${BUILDDIR}/usr/local/bin/mina-verify-packaged-fork-config"
  # Update the mina.service with a new default PEERS_URL based on Seed List \
  # URL $2
  mkdir -p "${BUILDDIR}/usr/lib/systemd/user/"
  sed "s%PEERS_LIST_URL_PLACEHOLDER%https://storage.googleapis.com/${2}%" \
    ../scripts/mina.service > "${BUILDDIR}/usr/lib/systemd/user/mina.service"

  # Copy the genesis ledgers and proofs as these are fairly small and very \
  # valuable to have
  # Genesis Ledger/proof/epoch ledger Copy
  for f in /tmp/coda_cache_dir/genesis*; do
      if [ -e "$f" ]; then
          mv /tmp/coda_cache_dir/genesis* "${BUILDDIR}/var/lib/coda/."
      fi
  done

  # Support bash completion
  # NOTE: We do not list bash-completion as a required package,
  #       but it needs to be present for this to be effective
  mkdir -p "${BUILDDIR}/etc/bash_completion.d"
  env COMMAND_OUTPUT_INSTALLATION_BASH=1 "${BUILDDIR}/usr/local/bin/mina" > \
    "${BUILDDIR}/etc/bash_completion.d/mina"
}

## LOGPROC PACKAGE ##
build_logproc_deb() {
  create_control_file mina-logproc "${SHARED_DEPS}" \
    'Utility for processing mina-daemon log output'

  # Binaries
  cp ./default/src/app/logproc/logproc.exe \
    "${BUILDDIR}/usr/local/bin/mina-logproc"

  build_deb mina-logproc
}
## END LOGPROC PACKAGE ##

## GENERATE TEST_EXECUTIVE PACKAGE ##
build_test_executive_deb () {
  create_control_file mina-test-executive \
    "${SHARED_DEPS}${TEST_EXECUTIVE_DEPS}" \
    'Tool to run automated tests against a full mina testnet with multiple \
    nodes.'

  # Binaries
  cp ./default/src/app/test_executive/test_executive.exe \
    "${BUILDDIR}/usr/local/bin/mina-test-executive"

  build_deb mina-test-executive
}
## END TEST_EXECUTIVE PACKAGE ##

## GENERATE BATCH TXN TOOL PACKAGE ##
build_batch_txn_deb() {

  create_control_file mina-batch-txn "${SHARED_DEPS}" \
    'Load transaction tool against a mina node.'

  # Binaries
  cp ./default/src/app/batch_txn_tool/batch_txn_tool.exe \
    "${BUILDDIR}/usr/local/bin/mina-batch-txn"

  build_deb mina-batch-txn
}
## END BATCH TXN TOOL PACKAGE ##

## GENERATE TEST SUITE PACKAGE ##
build_functional_test_suite_deb() {
  create_control_file mina-test-suite "${SHARED_DEPS}" \
    'Test suite apps for mina.'

  mkdir -p "${BUILDDIR}/etc/mina/test/archive"

  cp -r ../src/test/archive/* "${BUILDDIR}"/etc/mina/test/archive/

  # Binaries
  cp ./default/src/test/command_line_tests/command_line_tests.exe \
    "${BUILDDIR}/usr/local/bin/mina-command-line-tests"
  cp ./default/src/app/benchmarks/benchmarks.exe \
    "${BUILDDIR}/usr/local/bin/mina-benchmarks"
  cp ./default/src/app/ledger_export_bench/ledger_export_benchmark.exe \
    "${BUILDDIR}/usr/local/bin/mina-ledger-export-benchmark"
  cp ./default/src/app/disk_caching_stats/disk_caching_stats.exe \
    "${BUILDDIR}/usr/local/bin/mina-disk-caching-stats"
  cp ./default/src/app/heap_usage/heap_usage.exe \
    "${BUILDDIR}/usr/local/bin/mina-heap-usage"
  cp ./default/src/app/zkapp_limits/zkapp_limits.exe \
    "${BUILDDIR}/usr/local/bin/mina-zkapp-limits"
  cp ./default/src/test/archive/patch_archive_test/patch_archive_test.exe \
    "${BUILDDIR}/usr/local/bin/mina-patch-archive-test"
  cp ./default/src/test/archive/archive_node_tests/archive_node_tests.exe \
    "${BUILDDIR}/usr/local/bin/mina-archive-node-test"

  mkdir -p ${BUILDDIR}/etc/mina/test/archive/sample_db
  rsync -Huav ../src/test/archive/sample_db* "${BUILDDIR}/etc/mina/test/archive"

  build_deb mina-test-suite

}
## END TEST SUITE PACKAGE ##

function copy_common_rosetta_configs () {

  # Copy rosetta-based Binaries
  cp ./default/src/app/rosetta/rosetta.exe \
    "${BUILDDIR}/usr/local/bin/mina-rosetta"
  cp ./default/src/app/rosetta/ocaml-signer/signer.exe \
    "${BUILDDIR}/usr/local/bin/mina-ocaml-signer"

  mkdir -p "${BUILDDIR}/etc/mina/rosetta"
  mkdir -p "${BUILDDIR}/etc/mina/rosetta/rosetta-cli-config"
  mkdir -p "${BUILDDIR}/etc/mina/rosetta/scripts"

  # --- Copy artifacts
  cp ../src/app/rosetta/scripts/* "${BUILDDIR}/etc/mina/rosetta/scripts"
  cp ../src/app/rosetta/rosetta-cli-config/*.json \
    "${BUILDDIR}/etc/mina/rosetta/rosetta-cli-config"
  cp ../src/app/rosetta/rosetta-cli-config/*.ros \
    "${BUILDDIR}/etc/mina/rosetta/rosetta-cli-config"
  cp ./default/src/app/rosetta/indexer_test/indexer_test.exe \
    "${BUILDDIR}/usr/local/bin/mina-rosetta-indexer-test"

}

## ROSETTA MAINNET PACKAGE ##
build_rosetta_mainnet_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building mainnet rosetta deb"

  create_control_file mina-rosetta-mainnet "${SHARED_DEPS}" \
    'Mina Protocol Rosetta Client' "${SUGGESTED_DEPS}"

  copy_common_rosetta_configs "mainnet"

  build_deb mina-rosetta-mainnet
}
## END ROSETTA MAINNET PACKAGE ##

## ROSETTA DEVNET PACKAGE ##
build_rosetta_devnet_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building devnet rosetta deb"

  create_control_file mina-rosetta-devnet "${SHARED_DEPS}" \
    'Mina Protocol Rosetta Client' "${SUGGESTED_DEPS}"

  copy_common_rosetta_configs "testnet"

  build_deb mina-rosetta-devnet
}
## END ROSETTA DEVNET PACKAGE ##

## MAINNET PACKAGE ##
build_daemon_mainnet_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building mainnet deb without keys:"

  create_control_file mina-mainnet "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon' "${SUGGESTED_DEPS}"

  copy_common_daemon_configs mainnet 'mina-seed-lists/mainnet_seeds.txt'

  build_deb mina-mainnet
}
## END MAINNET PACKAGE ##

## DEVNET PACKAGE ##
build_daemon_devnet_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building testnet signatures deb without keys:"

  create_control_file mina-devnet "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon for the Devnet Network' "${SUGGESTED_DEPS}"

  copy_common_daemon_configs devnet 'seed-lists/devnet_seeds.txt'

  build_deb mina-devnet
}
## END DEVNET PACKAGE ##

## MAINNET LEGACY PACKAGE ##
build_daemon_mainnet_legacy_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building mainnet legacy deb without keys:"

  create_control_file mina-mainnet-legacy "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon' "${SUGGESTED_DEPS}"

  # Copy legacy binary
  cp ./default/src/app/cli/src/mina.exe \
    "${BUILDDIR}/usr/local/bin/mina-legacy"

  build_deb mina-mainnet-legacy
}
## END MAINNET LEGACY PACKAGE ##

## DEVNET LEGACY PACKAGE ##
build_daemon_devnet_legacy_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building testnet signatures legacy deb without keys:"

  create_control_file mina-devnet-legacy "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon for the Devnet Network' "${SUGGESTED_DEPS}"

  # Copy legacy binary
  cp ./default/src/app/cli/src/mina.exe \
    "${BUILDDIR}/usr/local/bin/mina-legacy"

  build_deb mina-devnet-legacy
}
## END DEVNET LEGACY PACKAGE ##

replace_runtime_config_and_ledgers_with_hardforked_ones() {
  local NETWORK_NAME="${1}"

  # Create the directory for the runtime config and ledgers if it doesn't exist
  mkdir -p "${BUILDDIR}/var/lib/coda"

  { [ -z ${RUNTIME_CONFIG_JSON+x} ] || [ -z ${LEDGER_TARBALLS+x} ]; }  \
    && echo "required env vars were not provided" && exit 1

  # Replace the runtime config and ledgers with the hardfork ones
  cp "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"
  for ledger_tarball in $LEDGER_TARBALLS; do
    cp "${ledger_tarball}" "${BUILDDIR}/var/lib/coda/"
  done

  # Overwrite outdated ledgers that are being updated by the hardfork (backing up the outdated ledgers)
  if [ -f "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.json" ]; then
    mv "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.json" "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.old.json"
  fi
  cp "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.json"
}


## DEVNET HARDFORK PACKAGE ##
build_daemon_devnet_hardfork_deb() {
  local __deb_name=mina-devnet-hardfork

  echo "------------------------------------------------------------"
  echo "--- Building hardfork testnet signatures deb without keys:"

  create_control_file "${__deb_name}" "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon for the Devnet Network' "${SUGGESTED_DEPS}"

  copy_common_daemon_configs devnet 'seed-lists/devnet_seeds.txt'

  replace_runtime_config_and_ledgers_with_hardforked_ones devnet

  build_deb "${__deb_name}"

}

## END DEVNET HARDFORK PACKAGE ##

## MAINNET HARDFORK PACKAGE ##
build_daemon_mainnet_hardfork_deb() {
  local __deb_name=mina-mainnet-hardfork

  echo "------------------------------------------------------------"
  echo "--- Building hardfork mainnet signatures deb without keys:"

  create_control_file "${__deb_name}" "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon for the Mainnet Network' "${SUGGESTED_DEPS}"

  copy_common_daemon_configs mainnet 'seed-lists/mainnet_seeds.txt'

  replace_runtime_config_and_ledgers_with_hardforked_ones mainnet

  build_deb "${__deb_name}"

}

## END MAINNET HARDFORK PACKAGE ##

copy_common_archive_configs() {
  local ARCHIVE_DEB="${1}"

  cp ./default/src/app/archive/archive.exe \
    "${BUILDDIR}/usr/local/bin/mina-archive"
  cp ./default/src/app/archive_blocks/archive_blocks.exe \
    "${BUILDDIR}/usr/local/bin/mina-archive-blocks"
  cp ./default/src/app/extract_blocks/extract_blocks.exe \
    "${BUILDDIR}/usr/local/bin/mina-extract-blocks"

  mkdir -p "${BUILDDIR}/etc/mina/archive"
  cp ../scripts/archive/missing-blocks-guardian.sh \
    "${BUILDDIR}/usr/local/bin/mina-missing-blocks-guardian"

  cp ./default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
    "${BUILDDIR}/usr/local/bin/mina-missing-blocks-auditor"
  cp ./default/src/app/replayer/replayer.exe \
    "${BUILDDIR}/usr/local/bin/mina-replayer"

  rsync -Huav ../src/app/archive/*.sql "${BUILDDIR}/etc/mina/archive"

  build_deb "$ARCHIVE_DEB"
}

## ARCHIVE DEVNET PACKAGE ##
build_archive_devnet_deb () {
  ARCHIVE_DEB=mina-archive-devnet

  echo "------------------------------------------------------------"
  echo "--- Building archive devnet deb"

  create_control_file "$ARCHIVE_DEB" "${ARCHIVE_DEPS}" 'Mina Archive Process
 Compatible with Mina Daemon'

  copy_common_archive_configs "$ARCHIVE_DEB"

}
## END ARCHIVE DEVNET PACKAGE ##

## ARCHIVE MAINNET PACKAGE ##
build_archive_mainnet_deb () {
  ARCHIVE_DEB=mina-archive-mainnet

  echo "------------------------------------------------------------"
  echo "--- Building archive mainnet deb"

  create_control_file "$ARCHIVE_DEB" "${ARCHIVE_DEPS}" 'Mina Archive Process
 Compatible with Mina Daemon'

  copy_common_archive_configs "$ARCHIVE_DEB"

}
## END ARCHIVE MAINNET PACKAGE ##

## ZKAPP TEST TXN ##
build_zkapp_test_transaction_deb () {
  echo "------------------------------------------------------------"
  echo "--- Building Mina Berkeley ZkApp test transaction tool:"

  create_control_file mina-zkapp-test-transaction \
    "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Utility to generate ZkApp transactions in Mina GraphQL format'

  # Binaries
  cp ./default/src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
    "${BUILDDIR}/usr/local/bin/mina-zkapp-test-transaction"

  build_deb mina-zkapp-test-transaction
}
## END ZKAPP TEST TXN PACKAGE ##


build_create_legacy_genesis_deb() {
  echo "------------------------------------------------------------"
  echo "--- Building Mina Berkeley create legacy genesis tool:"

  create_control_file mina-create-legacy-genesis \
    "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Utility to verify post hardfork ledger for Mina'

  # Binaries
  cp ./default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
    "${BUILDDIR}/usr/local/bin/mina-create-legacy-genesis"

  build_deb mina-create-legacy-genesis
}