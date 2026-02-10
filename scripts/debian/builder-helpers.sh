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


source "${SCRIPTPATH}/../export-git-env-vars.sh"


# SUGGESTED_DEPS should only be used for Suggests, not Depends.
SUGGESTED_DEPS="jq, curl, wget"

TEST_EXECUTIVE_DEPS=", mina-logproc, python3, docker-ce "

case "${MINA_DEB_CODENAME}" in
  noble)
    SHARED_DEPS="libssl3t64, libgmp10, libgomp1, tzdata, liblmdb0"
    DAEMON_DEPS=", libffi8, libjemalloc2, libpq-dev, libproc2-0, mina-logproc"
    ARCHIVE_DEPS="libssl3t64, libgomp1, libpq-dev, libjemalloc2"
    ;;
  jammy)
    SHARED_DEPS="libssl3, libgmp10, libgomp1, tzdata, liblmdb0"
    DAEMON_DEPS=", libffi8, libjemalloc2, libpq-dev, libprocps8, mina-logproc"
    ARCHIVE_DEPS="libssl3, libgomp1, libpq-dev, libjemalloc2"
  ;;
  bookworm)
    SHARED_DEPS="libssl3, libgmp10, libgomp1, tzdata, liblmdb0"
    DAEMON_DEPS=", libffi8, libjemalloc2, libpq-dev, libproc2-0, mina-logproc"
    ARCHIVE_DEPS="libssl3, libgomp1, libpq-dev, libjemalloc2"
    ;;
  bullseye|focal)
    SHARED_DEPS="libssl1.1, libgmp10, libgomp1, tzdata, liblmdb0"
    DAEMON_DEPS=", libffi7, libjemalloc2, libpq-dev, libprocps8, mina-logproc"
    ARCHIVE_DEPS="libssl1.1, libgomp1, libpq-dev, libjemalloc2"
    ;;
  *)
    echo "Unknown Debian codename provided: ${MINA_DEB_CODENAME}"; exit 1
    ;;
esac

MINA_DEB_NAME="mina-testnet-generic"
MINA_DEVNET_DEB_NAME="mina-devnet"
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
    MINA_DEB_NAME="${MINA_DEB_NAME}-${DEB_SUFFIX}"
    MINA_DEVNET_DEB_NAME="${MINA_DEVNET_DEB_NAME}-${DEB_SUFFIX}"
    ;;
esac


#Add suffix to debian to distinguish instrumented packages
if [[ -v DUNE_INSTRUMENT_WITH ]]; then
    INSTRUMENTED_SUFFIX=instrumented
    MINA_DEB_NAME="${MINA_DEB_NAME}-${INSTRUMENTED_SUFFIX}"
    DEB_SUFFIX="${DEB_SUFFIX}-${INSTRUMENTED_SUFFIX}"
fi

BUILDDIR="deb_build"


# For automode purpose. We need to control location for both runtimes
AUTOMODE_PRE_HF_DIR=${BUILDDIR}/usr/lib/mina/berkeley
AUTOMODE_POST_HF_DIR=${BUILDDIR}/usr/lib/mina/mesa

# Function to ease creation of Debian package control files
create_control_file() {

  echo "------------------------------------------------------------"
  echo "create_control_file inputs:"
  echo "Package Name: ${1}"
  echo "Dependencies: ${2}"
  echo "Description: ${3}"
  if [ -n "${4:-}" ]; then
    echo "Broken/Replaces: ${4}"
  fi
  # Make sure the directory exists
  mkdir -p "${BUILDDIR}/DEBIAN"

  # Also clean the binary directory that all packages need
  rm -rf "${BUILDDIR}/usr/local/bin"

  CONTROL="${BUILDDIR}/DEBIAN/control"

  # Create the control file itself
  cat << EOF > ${CONTROL}
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
EOF

  if [ -n "${2:-}" ]; then
    echo "Depends: ${2}" >> ${CONTROL}
  fi
  if [ -n "${4:-}" ]; then
    echo "Suggests: ${4}" >> ${CONTROL}
  fi
  if [ -n "${5:-}" ]; then
    echo "Replaces: ${5}" >> ${CONTROL}
    echo "Breaks: ${5}" >> ${CONTROL}
  fi

  cat <<EOF >> ${CONTROL}
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

copy_hf_related_scripts() {

  cp ../scripts/hardfork/create_runtime_config.sh \
    "${BUILDDIR}/usr/local/bin/mina-hf-create-runtime-config"
  cp ../scripts/hardfork/mina-verify-packaged-fork-config \
    "${BUILDDIR}/usr/local/bin/mina-verify-packaged-fork-config"

}

# Copies scripts and build utilities to debian package
copy_common_daemon_utils() {
  echo "------------------------------------------------------------"
  echo "copy_common_daemon_configs inputs:"
  echo "Seed List URL path: ${1} (like seed-lists/berkeley_seeds.txt)"

  local MINA_BIN="${2:-${BUILDDIR}/usr/local/bin/mina}"

  copy_hf_related_scripts

  # Update the mina.service with a new default PEERS_URL based on Seed List \
  # URL $1
  mkdir -p "${BUILDDIR}/usr/lib/systemd/user/"
  sed "s%PEERS_LIST_URL_PLACEHOLDER%https://storage.googleapis.com/${1}%" \
    ../scripts/mina.service > "${BUILDDIR}/usr/lib/systemd/user/mina.service"

  # Support bash completion
  # NOTE: We do not list bash-completion as a required package,
  #       but it needs to be present for this to be effective
  mkdir -p "${BUILDDIR}/etc/bash_completion.d"
  env COMMAND_OUTPUT_INSTALLATION_BASH=1 "${MINA_BIN}" > \
    "${BUILDDIR}/etc/bash_completion.d/mina"

}

# Copies common daemon binaries only to debian package
copy_common_daemon_apps() {

  echo "------------------------------------------------------------"
  echo "copy_common_daemon_apps inputs:"
  echo "Signature Type: ${1} (mainnet or testnet)"

  local TARGET_ROOT_DIR="${2:-${BUILDDIR}/usr/local/bin}"

  echo "Target Root Dir: ${TARGET_ROOT_DIR}"

  mkdir -p "${TARGET_ROOT_DIR}"

  cp ../src/app/libp2p_helper/result/bin/libp2p_helper \
    "${TARGET_ROOT_DIR}/coda-libp2p_helper"
  cp ./default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
    "${TARGET_ROOT_DIR}/mina-create-genesis"
  cp ./default/src/app/generate_keypair/generate_keypair.exe \
    "${TARGET_ROOT_DIR}/mina-generate-keypair"
  cp ./default/src/app/validate_keypair/validate_keypair.exe \
    "${TARGET_ROOT_DIR}/mina-validate-keypair"
  cp ./default/src/lib/snark_worker/standalone/run_snark_worker.exe \
    "${TARGET_ROOT_DIR}/mina-standalone-snark-worker"
  cp ./default/src/app/rocksdb-scanner/rocksdb_scanner.exe \
    "${TARGET_ROOT_DIR}/mina-rocksdb-scanner"

  # Copy signature-based Binaries (based on signature type $1 passed into the \
  # function)
  cp ./default/src/app/cli/src/mina_"${1}"_signatures.exe \
    "${TARGET_ROOT_DIR}/mina"

}

# Function to DRY copying config files into daemon packages
copy_common_daemon_configs() {

  echo "------------------------------------------------------------"
  echo "copy_common_daemon_configs inputs:"
  echo "Network Name: ${1} (like mainnet, devnet, berkeley)"

  local NETWORK_NAME="${1}"

  mkdir -p "${BUILDDIR}/var/lib/coda"

  # Include genesis ledgers for the network.
  # We want to copy the genesis ledger for the network ($1) and in case of
  # devnet/mainnet also copy the magic config (config_$GITHASH_CONFIG.json).
  # This config is automatically picked up by the daemon on startup.
  # In case of testnet-generic we only copy the devnet ledger without magic one
  # as testnet-generic should be testnet agnostic.
  case "${NETWORK_NAME}" in
    devnet|mainnet|mesa)
      cp ../genesis_ledgers/"${NETWORK_NAME}".json \
        "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"
      cp ../genesis_ledgers/${NETWORK_NAME}.json "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.json"
      ;;
    testnet-generic)
      cp ../genesis_ledgers/devnet.json "${BUILDDIR}/var/lib/coda/devnet.json"
      ;;
    *)
      echo "Unknown network name provided: ${NETWORK_NAME}"; exit 1
      ;;
  esac
}

function copy_common_rosetta_configs () {

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Copy rosetta-based Binaries
  cp ./default/src/app/rosetta/rosetta_"${1}"_signatures.exe \
    "${BUILDDIR}/usr/local/bin/mina-rosetta"
  cp ./default/src/app/rosetta/ocaml-signer/signer_"${1}"_signatures.exe \
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

## LOGPROC PACKAGE ##

#
# Builds mina-logproc package for log processing utility
#
# Output: mina-logproc_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS} (basic system libraries)
#
# Simple utility package containing only the logproc binary.
#
build_logproc_deb() {
  create_control_file mina-logproc "${SHARED_DEPS}" \
    'Utility for processing mina-daemon log output'

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/logproc/logproc.exe \
    "${BUILDDIR}/usr/local/bin/mina-logproc"

  build_deb mina-logproc
}
## END LOGPROC PACKAGE ##

## GENERATE TEST_EXECUTIVE PACKAGE ##

#
# Builds mina-test-executive package for automated testing
#
# Output: mina-test-executive_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${TEST_EXECUTIVE_DEPS} (includes docker, python3)
#
# Package for running automated tests against full mina testnets.
#
build_test_executive_deb () {
  create_control_file mina-test-executive \
    "${SHARED_DEPS}${TEST_EXECUTIVE_DEPS}" \
    'Tool to run automated tests against a full mina testnet with multiple \
    nodes.'

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/test_executive/test_executive.exe \
    "${BUILDDIR}/usr/local/bin/mina-test-executive"

  build_deb mina-test-executive
}
## END TEST_EXECUTIVE PACKAGE ##

## GENERATE BATCH TXN TOOL PACKAGE ##

#
# Builds mina-batch-txn package for transaction load testing
#
# Output: mina-batch-txn_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}
#
# Tool for generating transaction load against mina nodes.
#
build_batch_txn_deb() {

  create_control_file mina-batch-txn "${SHARED_DEPS}" \
    'Load transaction tool against a mina node.'

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/batch_txn_tool/batch_txn_tool.exe \
    "${BUILDDIR}/usr/local/bin/mina-batch-txn"

  build_deb mina-batch-txn
}
## END BATCH TXN TOOL PACKAGE ##

## GENERATE TEST SUITE PACKAGE ##

#
# Builds mina-test-suite package containing various testing utilities
#
# Output: mina-test-suite_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}
#
# Comprehensive package with command line tests, benchmarks, archive tests,
# and performance analysis tools. Includes sample database for archive testing.
#
build_functional_test_suite_deb() {
  create_control_file mina-test-suite "${SHARED_DEPS}" \
    'Test suite apps for mina.'

  mkdir -p "${BUILDDIR}/etc/mina/test/archive"

  mkdir -p "${BUILDDIR}/usr/local/bin"

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

## ROSETTA MAINNET PACKAGE ##

#
# Builds mina-rosetta-mainnet package for mainnet Rosetta API
#
# Output: mina-rosetta-mainnet_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}
#
# Rosetta API implementation for mainnet with mainnet signature binaries.
#
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

#
# Builds mina-rosetta-devnet package for devnet Rosetta API
#
# Output: mina-rosetta-devnet_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}
#
# Rosetta API implementation for devnet with testnet signature binaries.
#
build_rosetta_devnet_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building devnet rosetta deb"

  create_control_file mina-rosetta-devnet "${SHARED_DEPS}" \
    'Mina Protocol Rosetta Client' "${SUGGESTED_DEPS}"

  copy_common_rosetta_configs "testnet"

  build_deb mina-rosetta-devnet
}
## END ROSETTA DEVNET PACKAGE ##

## ROSETTA GENERIC TESTNET PACKAGE ##

#
# Builds mina-rosetta-testnet-generic package for Generic testnet Rosetta API
#
# Output: mina-rosetta-testnet-generic_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}
#
# Rosetta API implementation for testnet-generic testnet with testnet signature binaries.
#
build_rosetta_testnet_generic_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building testnet-generic rosetta deb"

  create_control_file mina-rosetta-testnet-generic "${SHARED_DEPS}" \
    'Mina Protocol Rosetta Client' "${SUGGESTED_DEPS}"

  copy_common_rosetta_configs "testnet"

  build_deb mina-rosetta-testnet-generic
}
## END GENERIC TESTNET PACKAGE ##

## ROSETTA MESA PACKAGE ##

#
# Builds mina-rosetta-mesa package for Mesa testnet Rosetta API
#
# Output: mina-rosetta-mesa_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}
#
# Rosetta API implementation for Mesa testnet with testnet signature binaries.
#
build_rosetta_mesa_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building mesa rosetta deb"

  create_control_file mina-rosetta-mesa "${SHARED_DEPS}" \
    'Mina Protocol Rosetta Client' "${SUGGESTED_DEPS}"

  copy_common_rosetta_configs "testnet"

  build_deb mina-rosetta-mesa
}
## END ROSETTA MESA PACKAGE ##

## MAINNET PACKAGE ##

#
# Builds mina-mainnet package for mainnet daemon
#
# Output: mina-mainnet_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS} (includes libpq-dev, jemalloc, logproc)
#
# Full mainnet daemon package with mainnet signatures and mainnet genesis ledger
# as default. Uses mainnet seed list and mainnet configuration.
#
build_daemon_mainnet_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building mainnet apps deb without keys:"

  create_control_file mina-mainnet "${SHARED_DEPS}${DAEMON_DEPS}, mina-mainnet-config (>=${MINA_DEB_VERSION})" \
    'Mina Protocol Client and Daemon' "${SUGGESTED_DEPS}" "mina-mainnet (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_apps mainnet

  copy_common_daemon_utils 'mina-seed-lists/mainnet_seeds.txt'

  build_deb mina-mainnet
}

build_daemon_mainnet_config_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building mainnet config deb without keys:"

  # Remove SUGGESTED_DEPS from Depends, add as Suggests instead.
  create_control_file mina-mainnet-config "" \
    'Mina Protocol Client and Daemon' "${SUGGESTED_DEPS}" "mina-mainnet (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_configs mainnet

  build_deb mina-mainnet-config
}
## END MAINNET PACKAGE ##

## DEVNET PACKAGE ##

#
# Builds devnet daemon package with profile-aware naming
#
# Output: ${MINA_DEVNET_DEB_NAME}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Where MINA_DEVNET_DEB_NAME can be:
#   - "mina-devnet" (default)
#   - "mina-devnet-lightnet" (if DUNE_PROFILE=lightnet)
#   - "mina-devnet-instrumented" (if DUNE_INSTRUMENT_WITH is set)
#   - "mina-devnet-lightnet-instrumented" (both conditions)
#
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Devnet daemon with testnet signatures and devnet genesis ledger as default.
# Package name includes suffixes for different profiles and instrumentation.
#
build_daemon_devnet_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building testnet signatures deb without keys:"

  create_control_file "${MINA_DEVNET_DEB_NAME}" "${SHARED_DEPS}${DAEMON_DEPS}, mina-devnet-config (>=${MINA_DEB_VERSION})" \
    'Mina Protocol Client and Daemon for the Devnet Network' "${SUGGESTED_DEPS}" "${MINA_DEVNET_DEB_NAME} (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_apps testnet

  copy_common_daemon_utils 'seed-lists/devnet_seeds.txt'

  build_deb "${MINA_DEVNET_DEB_NAME}"
}

build_daemon_devnet_config_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building testnet signatures config deb without keys:"

  create_control_file mina-devnet-config "" \
    'Mina Protocol Client and Daemon for the Devnet Network' "${SUGGESTED_DEPS}" "mina-devnet (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_configs devnet

  build_deb mina-devnet-config
}
## END DEVNET PACKAGE ##

## MESA PACKAGE ##

#
# Builds mesa daemon package with profile-aware naming
#
# Output: ${MINA_DEVNET_DEB_NAME}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Where MINA_DEVNET_DEB_NAME can be:
#   - "mina-mesa" (default)
#   - "mina-mesa-lightnet" (if DUNE_PROFILE=lightnet)
#   - "mina-mesa-instrumented" (if DUNE_INSTRUMENT_WITH is set)
#   - "mina-mesa-lightnet-instrumented" (both conditions)
#
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Mesa daemon with testnet signatures and devnet genesis ledger as default.
# Package name includes suffixes for different profiles and instrumentation.
#
build_daemon_mesa_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building testnet signatures deb without keys:"

  create_control_file "mina-mesa" "${SHARED_DEPS}${DAEMON_DEPS}, mina-mesa-config (>=${MINA_DEB_VERSION})" \
    'Mina Protocol Client and Daemon for the Devnet Network' "${SUGGESTED_DEPS}" "mina-mesa (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_apps testnet

  copy_common_daemon_utils 'o1labs-gitops-infrastructure/mina-mesa-network/mina-mesa-network-seeds.txt'

  build_deb "mina-mesa"
}

build_daemon_mesa_config_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building testnet signatures config deb without keys:"

  create_control_file mina-mesa-config "" \
    'Mina Protocol Client and Daemon for the Mesa Network' "${SUGGESTED_DEPS}" "mina-mesa (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_configs mesa

  build_deb mina-mesa-config
}

## END MESA PACKAGE ##

## MAINNET LEGACY PACKAGE ##

#
# Builds mina-mainnet-pre-hardfork-mesa tailored package for automode package
#
# Output: mina-mainnet-pre-hardfork-mesa_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Contains only the legacy mainnet binaries places in "/usr/lib/mina/berkeley" without
# configuration files or genesis ledgers.
#
build_daemon_mainnet_pre_hardfork_deb() {

  NAME="mina-mainnet-pre-hardfork-mesa"

  echo "------------------------------------------------------------"
  echo "--- Building mainnet berkeley deb for hardfork automode :"

  create_control_file $NAME "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon' "${SUGGESTED_DEPS}"

  copy_common_daemon_apps mainnet $AUTOMODE_PRE_HF_DIR

  build_deb $NAME
}
## END MAINNET LEGACY PACKAGE ##

## MESA LEGACY PACKAGE ##

#
# Builds mina-mesa-pre-hardfork-mesa tailored package for automode package
#
# Output: mina-mesa-pre-hardfork-mesa_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Contains only the legacy mesa binaries places in "/usr/lib/mina/berkeley" without
# configuration files or genesis ledgers.
#
build_daemon_mesa_pre_hardfork_deb() {

  NAME="mina-mesa-pre-hardfork-mesa"

  echo "------------------------------------------------------------"
  echo "--- Building mesa berkeley deb for hardfork automode :"

  create_control_file $NAME "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon' "${SUGGESTED_DEPS}"

  copy_common_daemon_apps testnet $AUTOMODE_PRE_HF_DIR

  build_deb $NAME
}
## END MESA LEGACY PACKAGE ##

## DEVNET LEGACY PACKAGE ##

#
# Builds mina-devnet-pre-hardfork-mesa tailored package for automode package
#
# Output: mina-devnet-pre-hardfork-mesa_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Contains only the legacy mainnet binaries places in "/usr/lib/mina/berkeley" without
# configuration files or genesis ledgers.
#
build_daemon_devnet_pre_hardfork_deb() {

  NAME="mina-devnet-pre-hardfork-mesa"

  echo "------------------------------------------------------------"
  echo "--- Building testnet devnet legacy deb for hardfork automode :"

  create_control_file $NAME "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon for the Devnet Network' "${SUGGESTED_DEPS}"

  copy_common_daemon_apps testnet $AUTOMODE_PRE_HF_DIR

  build_deb $NAME
}
## END DEVNET PRE HF PACKAGE ##

# Function to DRY creating symlinks for shared apps in deb packages
# for automode runtimes that share the same dispatcher but different runtimes
create_symlinks_for_shared_apps() {
  local NETWORK_NAME=${1}


  cp ../scripts/hardfork/dispatcher.sh \
    "${BUILDDIR}/usr/local/bin/mina-dispatch"

  mkdir -p "${BUILDDIR}/etc/default"

  #Create env vars for the dispatcher
    cat << EOF > "${BUILDDIR}/etc/default/mina-dispatch"
MINA_NETWORK=${NETWORK_NAME}
MINA_PROFILE="${DUNE_PROFILE}"
RUNTIMES_BASE_PATH="/usr/lib/mina"
MINA_LIBP2P_ENVVAR_NAME="MINA_LIBP2P_HELPER_PATH"
EOF


  # Create actual symlinks in the package (not using DEBIAN/links which is not standard)
  ln -sf mina-dispatch "${BUILDDIR}/usr/local/bin/coda-libp2p_helper"
  ln -sf mina-dispatch "${BUILDDIR}/usr/local/bin/mina-create-genesis"
  ln -sf mina-dispatch "${BUILDDIR}/usr/local/bin/mina-generate-keypair"
  ln -sf mina-dispatch "${BUILDDIR}/usr/local/bin/mina-validate-keypair"
  ln -sf mina-dispatch "${BUILDDIR}/usr/local/bin/mina-standalone-snark-worker"
  ln -sf mina-dispatch "${BUILDDIR}/usr/local/bin/mina-rocksdb-scanner"
  ln -sf mina-dispatch "${BUILDDIR}/usr/local/bin/mina"

  # Create directory for legacy binaries symlink if needed
  mkdir -p "${BUILDDIR}/usr/lib/mina/berkeley"
  ln -sf ../../lib/mina/berkeley/mina-create-genesis "${BUILDDIR}/usr/local/bin/mina-create-legacy-genesis"

  echo "------------------------------------------------------------"
  echo "Created symlinks in ${BUILDDIR}/usr/local/bin:"
  find "${BUILDDIR}/usr/local/bin/" -type l -exec ls -la {} \;

}

# Copies common binaries and configuration for post-hardfork automode packages
# Includes only binaries without configuration files or genesis ledgers
# Places binaries in /usr/lib/mina/<network_name> directory
copy_common_daemon_post_automode_apps_and_configs() {

  echo "------------------------------------------------------------"
  echo "copy_common_daemon_post_automode_configs inputs:"
  echo "Network Name: ${1} (like mainnet, devnet, berkeley)"
  echo "Signature Type: ${2} (mainnet or testnet)"
  echo "Seed List URL path: ${3} (like seed-lists/berkeley_seeds.txt)"

  # Copy binaries to separate directory as we need both berkeley and mesa binaries for automode packages
  # and they share the same dispatcher and some common apps,
  mkdir -p "${AUTOMODE_POST_HF_DIR}"
  copy_common_daemon_apps "${2}" $AUTOMODE_POST_HF_DIR

  # Create symlinks for shared apps in the main bin directory that
  # dispatch to the correct runtime based on env var set in /etc/default/mina-dispatch
  create_symlinks_for_shared_apps "${1}"

  copy_common_daemon_configs "${1}"

  # Copy seed list with correct URL for post-hardfork runtime and
  # bash completion that points to the correct seed list URL
  copy_common_daemon_utils "${3}" "${AUTOMODE_POST_HF_DIR}/mina"

}


build_daemon_mesa_postfork_deb() {

  NAME="mina-mesa-post-hardfork-mesa"

  echo "------------------------------------------------------------"
  echo "--- Building mesa post-hardfork deb for hardfork automode :"

  create_control_file $NAME "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon' "${SUGGESTED_DEPS}"

  copy_common_daemon_post_automode_apps_and_configs \
    "mesa" \
    "testnet" \
    'o1labs-gitops-infrastructure/mina-mesa-network/mina-mesa-network-seeds.txt'

  build_deb $NAME
}

build_daemon_devnet_postfork_deb() {

  NAME="mina-devnet-post-hardfork-mesa"

  echo "------------------------------------------------------------"
  echo "--- Building devnet post-hardfork deb for hardfork automode :"

  create_control_file $NAME "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon' "${SUGGESTED_DEPS}"

  copy_common_daemon_post_automode_apps_and_configs \
    "devnet" \
    "testnet" \
    'seed-lists/devnet_seeds.txt'

  build_deb $NAME
}


## TESTNET GENERIC PACKAGE ##

#
# Builds Testnet Generic testnet daemon package with profile-aware naming
#
# Output: ${MINA_DEB_NAME}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Where MINA_DEB_NAME can be:
#   - "mina-testnet-generic" (default)
#   - "mina-testnet-generic-lightnet" (if DUNE_PROFILE=lightnet)
#   - "mina-testnet-generic-instrumented" (if DUNE_INSTRUMENT_WITH is set)
#   - "mina-testnet-generic-lightnet-instrumented" (both conditions)
#
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Testnet Generic testnet daemon with testnet signatures and without any configs (like ledgers etc.).
# Package name includes suffixes for different profiles.
#
build_daemon_testnet_generic_deb() {

  echo "------------------------------------------------------------"
  echo "--- Building Mina Testnet Generic testnet signatures deb without keys:"

  create_control_file "${MINA_DEB_NAME}" "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon for the Generic Testnet Network' \
    "${SUGGESTED_DEPS}" "mina-devnet (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_apps testnet

  # copy devnet config just in case, but not as magic config, so it won't get picked up by default
  # when starting the daemon
  copy_common_daemon_configs testnet-generic

  copy_common_daemon_utils 'seed-lists/devnet_seeds.txt'

  build_deb "${MINA_DEB_NAME}"

}
## END TESTNET GENERIC PACKAGE ##

copy_common_daemon_hardfork_configs() {
  local NETWORK_NAME="${1}"

  # Copy build config and ledgers
  copy_common_daemon_configs ${NETWORK_NAME}

  { [ -z ${RUNTIME_CONFIG_JSON+x} ] || [ -z ${LEDGER_TARBALLS+x} ]; }  \
    && echo "required env vars were not provided" && exit 1

  # Replace ledgers
  cp -r "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"
  for ledger_tarball in $LEDGER_TARBALLS; do
    cp "${ledger_tarball}" "${BUILDDIR}/var/lib/coda/"
  done

  # Copy older genesis ledger as .old.json for backwards compatibility
  cp "../genesis_ledgers/${NETWORK_NAME}.json" "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.old.json"

  cp "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.json"
}


## DEVNET HARDFORK PACKAGE ##

#
# Builds mina-devnet-hardfork package for devnet hardfork
#
# Output: mina-devnet-hardfork_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Devnet daemon package with hardfork-specific runtime config and ledgers.
# Requires RUNTIME_CONFIG_JSON and LEDGER_TARBALLS environment variables.
#
build_daemon_devnet_hardfork_config_deb() {
  local __deb_name=mina-devnet-config

  echo "------------------------------------------------------------"
  echo "--- Building hardfork config testnet signatures deb without keys:"

  create_control_file "${__deb_name}" "" \
    'Mina Protocol Client and Daemon for the Devnet Network' "${SUGGESTED_DEPS}" "mina-devnet (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_hardfork_configs devnet

  build_deb "${__deb_name}"

}

## END DEVNET HARDFORK PACKAGE ##

## TESTNET GENERIC  HARDFORK PACKAGE ##

#
# Builds mina-testnet-generic-hardfork package for Testnet Generic hardfork
#
# Output: mina-testnet-generic-hardfork_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Testnet Generic daemon package with hardfork-specific runtime config and ledgers.
# Requires RUNTIME_CONFIG_JSON and LEDGER_TARBALLS environment variables.
#
build_daemon_testnet_generic_hardfork_config_deb() {
  local __deb_name=mina-testnet-generic-config

  echo "------------------------------------------------------------"
  echo "--- Building hardfork config testnet-generic signatures deb without keys:"

  create_control_file "${__deb_name}" "" \
    'Mina Protocol Client and Daemon for the Berkeley Network' "${SUGGESTED_DEPS}" \
    "mina-testnet-generic (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_hardfork_configs berkeley

  build_deb "${__deb_name}"
}

build_daemon_berkeley_hardfork_deb() {
  local __deb_name=mina-berkeley

  echo "------------------------------------------------------------"
  echo "--- Building hardfork Berkeley testnet signatures deb without keys:"

  create_control_file "${__deb_name}" "${SHARED_DEPS}${DAEMON_DEPS}, ${__deb_name}-config (>=${MINA_DEB_VERSION}) " \
    'Mina Protocol Client and Daemon for the Berkeley Network' \
    "${SUGGESTED_DEPS}" "mina-berkeley (<< ${MINA_DEB_VERSION})"


  replace_runtime_config_and_ledgers_with_hardforked_ones testnet-generic
  build_deb "${__deb_name}"

}

## END TESTNET GENERIC HARDFORK PACKAGE ##

## MAINNET HARDFORK PACKAGE ##

#
# Builds mina-mainnet-hardfork config package for mainnet hardfork
#
# Output: mina-mainnet-hardfork_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Mainnet daemon package with hardfork-specific runtime config and ledgers.
# Requires RUNTIME_CONFIG_JSON and LEDGER_TARBALLS environment variables.
# Note: Uses testnet signatures despite being mainnet hardfork package.
#
build_daemon_mainnet_hardfork_config_deb() {
  local __deb_name=mina-mainnet-config

  echo "------------------------------------------------------------"
  echo "--- Building hardfork mainnet signatures deb without keys:"

  create_control_file "${__deb_name}" "" \
    'Mina Protocol Client and Daemon for the Mainnet Network' "${SUGGESTED_DEPS}" \
    "mina-mainnet (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_hardfork_configs mainnet

  build_deb "${__deb_name}"

}

## END MAINNET HARDFORK PACKAGE ##

#
# Copies common binaries and configuration for archive packages
#
# Parameters:
#   $1 - Archive package name (used for build_deb call)
#
# Sets up archive daemon, archive blocks tool, extract blocks tool,
# missing blocks utilities, replayer, and SQL migration scripts.
#
copy_common_archive_configs() {
  local ARCHIVE_DEB="${1}"

  mkdir -p "${BUILDDIR}/usr/local/bin"

  cp ./default/src/app/archive/archive.exe \
    "${BUILDDIR}/usr/local/bin/mina-archive"
  cp ./default/src/app/archive_blocks/archive_blocks.exe \
    "${BUILDDIR}/usr/local/bin/mina-archive-blocks"
  cp ./default/src/app/extract_blocks/extract_blocks.exe \
    "${BUILDDIR}/usr/local/bin/mina-extract-blocks"
  cp ./default/src/app/archive_hardfork_toolbox/archive_hardfork_toolbox.exe \
    "${BUILDDIR}/usr/local/bin/mina-archive-hardfork-toolbox"

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

#
# Builds mina-archive-devnet package for devnet archive node
#
# Output: mina-archive-devnet_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${ARCHIVE_DEPS} (libssl, libgomp, libpq-dev, libjemalloc)
#
# Archive node package for devnet with all archive utilities and SQL scripts.
#
build_archive_devnet_deb () {
  ARCHIVE_DEB=mina-archive-devnet

  echo "------------------------------------------------------------"
  echo "--- Building archive devnet deb"

  create_control_file "$ARCHIVE_DEB" "${ARCHIVE_DEPS}" 'Mina Archive Process
 Compatible with Mina Daemon'

  copy_common_archive_configs "$ARCHIVE_DEB"

}
## END ARCHIVE DEVNET PACKAGE ##

## ARCHIVE GENERIC TESTNET PACKAGE ##

#
# Builds Generic testnet archive package with profile-aware naming
#
# Output: mina-archive-testnet-generic${DEB_SUFFIX}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Where DEB_SUFFIX can be:
#   - "" (empty, default)
#   - "-lightnet" (if DUNE_PROFILE=lightnet)
#   - "-instrumented" (if DUNE_INSTRUMENT_WITH is set)
#   - "-lightnet-instrumented" (both conditions)
#
# Dependencies: ${ARCHIVE_DEPS}
#
# Archive node package for Generic testnet with suffix-aware naming for different profiles.
#
build_archive_testnet_generic_deb () {
  ARCHIVE_DEB=mina-archive-testnet-generic${DEB_SUFFIX}

  echo "------------------------------------------------------------"
  echo "--- Building archive testnet-generic deb"


  create_control_file "$ARCHIVE_DEB" "${ARCHIVE_DEPS}" 'Mina Archive Process
 Compatible with Mina Daemon'

  copy_common_archive_configs "$ARCHIVE_DEB"

}
## END ARCHIVE BERKELEY PACKAGE ##

## ARCHIVE MESA PACKAGE ##

#
# Builds Mesa archive package with profile-aware naming
#
# Output: mina-archive-mesa${DEB_SUFFIX}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Where DEB_SUFFIX can be:
#   - "" (empty, default)
#   - "-lightnet" (if DUNE_PROFILE=lightnet)
#   - "-instrumented" (if DUNE_INSTRUMENT_WITH is set)
#   - "-lightnet-instrumented" (both conditions)
#
# Dependencies: ${ARCHIVE_DEPS}
#
# Archive node package for Mesa with suffix-aware naming for different profiles.
#
build_archive_mesa_deb () {
  ARCHIVE_DEB=mina-archive-mesa${DEB_SUFFIX}

  echo "------------------------------------------------------------"
  echo "--- Building archive mesa deb"


  create_control_file "$ARCHIVE_DEB" "${ARCHIVE_DEPS}" 'Mina Archive Process
 Compatible with Mina Daemon'

  copy_common_archive_configs "$ARCHIVE_DEB"

}
## END ARCHIVE MESA PACKAGE ##

## ARCHIVE MAINNET PACKAGE ##

#
# Builds mina-archive-mainnet package for mainnet archive node
#
# Output: mina-archive-mainnet_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${ARCHIVE_DEPS}
#
# Archive node package for mainnet with all archive utilities and SQL scripts.
#
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

#
# Builds mina-zkapp-test-transaction package for zkApp testing
#
# Output: mina-zkapp-test-transaction_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Utility for generating zkApp transactions in Mina GraphQL format for testing.
#
build_zkapp_test_transaction_deb () {
  echo "------------------------------------------------------------"
  echo "--- Building Mina Generic testnet ZkApp test transaction tool:"

  create_control_file mina-zkapp-test-transaction \
    "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Utility to generate ZkApp transactions in Mina GraphQL format'

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
    "${BUILDDIR}/usr/local/bin/mina-zkapp-test-transaction"

  build_deb mina-zkapp-test-transaction
}
## END ZKAPP TEST TXN PACKAGE ##

#
# Builds mina-delegation-verify package for delegation verification
#
# Output: mina-delegation-verify_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Utility for verifying delegation in Mina GraphQL format.
#
build_delegation_verify_deb () {
  echo "------------------------------------------------------------"
  echo "--- Building Mina Berkeley delegation verify tool:"

  create_control_file mina-delegation-verify \
    "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Utility to verify delegation in Mina GraphQL format'

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/delegation_verify/delegation_verify.exe \
    "${BUILDDIR}/usr/local/bin/mina-delegation-verify"

  mkdir -p "${BUILDDIR}/etc/mina/aws"

  cp ./../src/app/delegation_verify/scripts/authenticate.sh \
    "${BUILDDIR}/etc/mina/aws/authenticate.sh"

  build_deb mina-delegation-verify
}
## END DELEGATION VERIFY PACKAGE ##


## CREATE LEGACY GENESIS PACKAGE ##

#
# Builds mina-create-legacy-genesis package for legacy genesis creation
#
# Output: mina-create-legacy-genesis_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Utility for creating legacy genesis ledgers for post-hardfork verification.
# Contains the runtime_genesis_ledger tool for Mina protocol.
#
build_prefork_genesis_ledger_deb() {
  echo "------------------------------------------------------------"
  echo "--- Building Mina Generic testnet create legacy genesis tool:"

  create_control_file mina-create-legacy-genesis \
    "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Utility to verify post hardfork ledger for Mina'

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
    "${BUILDDIR}/usr/local/bin/mina-create-prefork-genesis"

  build_deb mina-create-prefork-genesis
}
## END CREATE LEGACY GENESIS PACKAGE ##
