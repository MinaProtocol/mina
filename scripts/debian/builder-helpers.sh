#!/bin/bash
set -euo pipefail

SCRIPTPATH="${SCRIPTPATH:-"$( cd "$(dirname "$0")" ; pwd -P )"}"
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

MINA_DEB_NAME="mina-devnet"
MINA_ARCHIVE_DEB_NAME="mina-archive-devnet"
DUNE_PROFILE="${DUNE_PROFILE:-dev}"
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
    MINA_ARCHIVE_DEB_NAME="${MINA_ARCHIVE_DEB_NAME}-${DEB_SUFFIX}"
    ;;
esac


#Add suffix to debian to distinguish instrumented packages
if [[ -v DUNE_INSTRUMENT_WITH ]]; then
    INSTRUMENTED_SUFFIX=instrumented
    MINA_DEB_NAME="${MINA_DEB_NAME}-${INSTRUMENTED_SUFFIX}"
    MINA_ARCHIVE_DEB_NAME="${MINA_ARCHIVE_DEB_NAME}-${INSTRUMENTED_SUFFIX}"
    DEB_SUFFIX="${DEB_SUFFIX}-${INSTRUMENTED_SUFFIX}"
fi

BUILDDIR="deb_build"

# Function to ease creation of Debian package control files
create_control_file() {

  echo "create_control_file inputs:"
  echo "Package Name: ${1}"
  echo "Dependencies: ${2}"
  echo "Description: ${3}"
  if [ -n "${4:-}" ]; then
    echo "Suggests: ${4}"
  fi
  if [ -n "${5:-}" ]; then
    echo "Replaces/Breaks: ${5}"
  fi
  if [ -n "${6:-}" ]; then
    echo "Provides: ${6}"
  fi
  if [ -n "${7:-}" ]; then
    echo "Conflicts: ${7}"
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
  if [ -n "${6:-}" ]; then
    echo "Provides: ${6}" >> ${CONTROL}
  fi
  if [ -n "${7:-}" ]; then
    echo "Conflicts: ${7}" >> ${CONTROL}
  fi

  cat <<EOF >> ${CONTROL}
Section: base
Priority: optional
Homepage: https://minaprotocol.com/
Description:
 ${3}
 Built from ${GITHASH} by ${BUILD_URL}
EOF

  echo "Control File:"
  cat "${BUILDDIR}/DEBIAN/control"

}

# Function to ease package build
build_deb() {
  local package_name="$1"
  local deb_file="${package_name}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb"

  # Memoize: if this .deb was already produced (e.g. daemon_mainnet_generic and
  # daemon_devnet_generic both produce mina-generic), skip the second build.
  # Only in non-capture mode (tests need fresh captures).
  if [[ -z "${BUILD_DEB_CAPTURE_DIR:-}" ]] && [[ -f "$deb_file" ]]; then
    echo "Skipping ${deb_file} (already built)"
    rm -rf "${BUILDDIR}"
    return 0
  fi

  echo "Building ${deb_file}"
  echo "Package Name: ${package_name}"

  # echo contents of deb
  echo "Deb Contents:"
  find "${BUILDDIR}"

  # If BUILD_DEB_CAPTURE_DIR is set (used by tests), capture the staging
  # directory state to that directory instead of invoking fakeroot/dpkg-deb.
  if [[ -n "${BUILD_DEB_CAPTURE_DIR:-}" ]]; then
    echo "${package_name}" > "${BUILD_DEB_CAPTURE_DIR}/deb_name"
    cp "${BUILDDIR}/DEBIAN/control" "${BUILD_DEB_CAPTURE_DIR}/control"
    (cd "${BUILDDIR}" && find . -type f | sort) > "${BUILD_DEB_CAPTURE_DIR}/files"
    rm -rf "${BUILD_DEB_CAPTURE_DIR}/last_build"
    cp -a "${BUILDDIR}" "${BUILD_DEB_CAPTURE_DIR}/last_build"
    rm -rf "${BUILDDIR}"
    echo "Captured ${package_name} staging directory to ${BUILD_DEB_CAPTURE_DIR}"
    return 0
  fi

  # Build the package
  # NOTE: the reason for `-Zgzip` is we might be building on newer Ubuntu, e.g.
  # Noble. The default packaging format is `zstd`, but then when we're building
  # Docker image, we're examining those packages in buildkite's agent, where
  # `zstd` might not be available.
  fakeroot dpkg-deb -Zgzip --build "${BUILDDIR}" \
    "${package_name}"_"${MINA_DEB_VERSION}"_"${ARCHITECTURE}".deb
  echo "build_deb outputs:"
  ls -lh "${package_name}"_*.deb
  echo "deleting BUILDDIR ${BUILDDIR}"
  rm -rf "${BUILDDIR}"
}

copy_hf_related_scripts() {

  cp ../scripts/hardfork/create_runtime_config.sh \
    "${BUILDDIR}/usr/local/bin/mina-hf-create-runtime-config"
  cp ../scripts/hardfork/mina-verify-packaged-fork-config \
    "${BUILDDIR}/usr/local/bin/mina-verify-packaged-fork-config"

}

# Installs the mina.service systemd unit with the network-specific seed peer URL.
install_mina_service() {
  local network="$1"

  case "${network}" in
    mainnet)
      local seed_list_url='mina-seed-lists/mainnet_seeds.txt'
      ;;
    devnet)
      local seed_list_url='seed-lists/devnet_seeds.txt'
      ;;
    mesa|mesa-mut)
      local seed_list_url='o1labs-gitops-infrastructure/mina-mesa-network/mina-mesa-network-seeds.txt'
      ;;
    *)
      echo "Unknown network name provided: ${network}"; exit 1
      ;;
  esac

  mkdir -p "${BUILDDIR}/usr/lib/systemd/user/"
  sed "s%PEERS_LIST_URL_PLACEHOLDER%https://storage.googleapis.com/${seed_list_url}%" \
    ../scripts/mina.service > "${BUILDDIR}/usr/lib/systemd/user/mina.service"
}

# Copies hardfork scripts and generates bash completion into a debian package.
# Does NOT install mina.service (the config package owns it, see
# install_mina_service).
copy_common_daemon_utils() {
  echo "copy_common_daemon_utils inputs:"

  local MINA_BIN="${1:-${BUILDDIR}/usr/local/bin/mina}"

  copy_hf_related_scripts

  # Support bash completion
  # NOTE: We do not list bash-completion as a required package,
  #       but it needs to be present for this to be effective
  mkdir -p "${BUILDDIR}/etc/bash_completion.d"
  env COMMAND_OUTPUT_INSTALLATION_BASH=1 "${MINA_BIN}" > \
    "${BUILDDIR}/etc/bash_completion.d/mina"

}

# Copies common daemon binaries only to debian package
copy_common_daemon_apps() {

  echo "copy_common_daemon_apps inputs:"

  local TARGET_ROOT_DIR="${1:-${BUILDDIR}/usr/local/bin}"

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
  cp ./default/src/app/mina_healthcheck/mina_healthcheck.exe \
    "${TARGET_ROOT_DIR}/mina-healthcheck"

  cp ./default/src/app/cli/src/mina.exe \
    "${TARGET_ROOT_DIR}/mina"

  # GraphQL client utility (used by CI scripts; replaces ad-hoc curl invocations)
  cp ./default/src/app/mina_graphql_client/mina_graphql_client_app.exe \
    "${TARGET_ROOT_DIR}/mina-graphql-client"

}

# Function to DRY copying config files into daemon packages
copy_common_daemon_configs() {

  echo "copy_common_daemon_configs inputs:"
  echo "Network Name: ${1} (like mainnet, devnet)"

  local NETWORK_NAME="${1}"

  mkdir -p "${BUILDDIR}/var/lib/coda"

  # Include genesis ledgers for the network.
  # We want to copy the genesis ledger for the network ($1) and in case of
  # devnet/mainnet also copy the magic config (config_$GITHASH_CONFIG.json).
  # This config is automatically picked up by the daemon on startup.
  # mesa-mut is the mutable variant of the mesa network: it has no genesis
  # ledger of its own and reuses mesa's genesis ledger as its source.
  local LEDGER_SOURCE="${NETWORK_NAME}"
  case "${NETWORK_NAME}" in
    mesa-mut)
      LEDGER_SOURCE="mesa"
      ;;
  esac

  case "${NETWORK_NAME}" in
    devnet|mainnet|mesa|mesa-mut)
      cp ../genesis_ledgers/"${LEDGER_SOURCE}".json \
        "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"
      cp ../genesis_ledgers/${LEDGER_SOURCE}.json "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.json"
      ;;
    *)
      echo "Unknown network name provided: ${NETWORK_NAME}"; exit 1
      ;;
  esac
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

## GENERATE MINIMINA PACKAGE ##

#
# Builds minimina package for local Mina network tool
#
# Output: minimina_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: none (standalone Rust binary)
#
# The binary is expected at src/app/minimina/target/release/minimina
# after running: cargo build --release --manifest-path src/app/minimina/Cargo.toml
#
build_minimina_deb() {
  create_control_file minimina "" \
    'MiniMina - command line tool for spinning up local Mina networks'

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binary built by cargo
  cp ../src/app/minimina/target/release/minimina \
    "${BUILDDIR}/usr/local/bin/minimina"

  build_deb minimina
}
## END MINIMINA PACKAGE ##

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

## GENERATE TX TOOLS PACKAGE ##

#
# Builds mina-tx-tools package containing both transaction-testing binaries
#
# Output: mina-tx-tools_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS} (zkapp tool needs daemon deps)
#
# Ships both binaries that previously lived in the standalone mina-batch-txn
# and mina-zkapp-test-transaction packages, which no longer exist.
#
build_tx_tools_deb() {
  echo "--- Building mina-tx-tools (batch-txn + zkapp-test-transaction):"

  # Replaces/Breaks lets apt cleanly take over /usr/local/bin/mina-batch-txn
  # and /usr/local/bin/mina-zkapp-test-transaction from the older standalone
  # packages of those names (removed in favour of this consolidated package).
  create_control_file mina-tx-tools "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina transaction testing tools: load-test (batch-txn) and zkApp transaction generator.' \
    "" \
    "mina-batch-txn (<< ${MINA_DEB_VERSION}), mina-zkapp-test-transaction (<< ${MINA_DEB_VERSION})"

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/batch_txn_tool/batch_txn_tool.exe \
    "${BUILDDIR}/usr/local/bin/mina-batch-txn"
  cp ./default/src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
    "${BUILDDIR}/usr/local/bin/mina-zkapp-test-transaction"

  build_deb mina-tx-tools
}
## END TX TOOLS PACKAGE ##

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
  cp ./default/src/test/node_status_mock_server/node_status_mock_server.exe \
    "${BUILDDIR}/usr/local/bin/mina-node-status-mock-server"

  mkdir -p ${BUILDDIR}/etc/mina/test/archive/sample_db
  rsync -Huav ../src/test/archive/sample_db* "${BUILDDIR}/etc/mina/test/archive"

  build_deb mina-test-suite

}
## END TEST SUITE PACKAGE ##

## ROSETTA GENERIC PACKAGE ##

#
# Builds mina-rosetta-generic package for Rosetta API without network awareness
#
# Output: mina-rosetta-generic_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}
#
# Rosetta API implementation
#
build_rosetta_generic_deb() {

  echo "--- Building rosetta generic deb"

  local package_name="mina-rosetta-generic${DEB_SUFFIX}"

  create_control_file "${package_name}" "${SHARED_DEPS}" \
    'Mina Protocol Rosetta Generic' "${SUGGESTED_DEPS}"

  mkdir -p "${BUILDDIR}/usr/local/bin"


  # Copy rosetta-based Binaries
  cp "./default/src/app/rosetta/rosetta.exe" \
    "${BUILDDIR}/usr/local/bin/mina-rosetta"
  cp "./default/src/app/rosetta/ocaml-signer/signer.exe" \
    "${BUILDDIR}/usr/local/bin/mina-ocaml-signer"

  mkdir -p "${BUILDDIR}/etc/mina/rosetta/"{rosetta-cli-config,scripts}

  # --- Copy artifacts
  cp ../src/app/rosetta/scripts/* "${BUILDDIR}/etc/mina/rosetta/scripts"
  cp ../src/app/rosetta/rosetta-cli-config/*.json \
    "${BUILDDIR}/etc/mina/rosetta/rosetta-cli-config"
  cp ../src/app/rosetta/rosetta-cli-config/*.ros \
    "${BUILDDIR}/etc/mina/rosetta/rosetta-cli-config"
  cp ./default/src/app/rosetta/indexer_test/indexer_test.exe \
    "${BUILDDIR}/usr/local/bin/mina-rosetta-indexer-test"

  build_deb "${package_name}"
}
## END ROSETTA GENERIC PACKAGE ##

## ROSETTA PACKAGE ##

#
# Builds mina-rosetta-NETWORK package for Rosetta API on specified network
#
# Output: mina-rosetta-${NETWORK}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}
#
# Rosetta API implementation for specified network
#
build_rosetta_deb() {

  local network="$1"

  local profile
  case "${network}" in
    mainnet) profile="mainnet" ;;
    devnet|mesa|mesa-mut) profile="devnet" ;;
    *) echo "Unknown network: ${network}" >&2; exit 1 ;;
  esac

  echo "--- Building ${network} rosetta tent metapackage"

  local package_name="mina-rosetta-${network}${DEB_SUFFIX}"

  local depends="mina-rosetta-generic${DEB_SUFFIX} (>= ${MINA_DEB_VERSION}), mina-${profile}-profile (>= ${MINA_DEB_VERSION})"

  create_control_file "${package_name}" "${depends}" \
    "Mina Protocol Rosetta Client for ${network}"

  build_deb "${package_name}"
}
## END ROSETTA PACKAGE ##

## PROFILE PACKAGE ##
build_profile_deb() {

  local profile="${1}"

  # The per-profile daemon layer that sits between the network-free
  # mina-generic package and the per-network mina-${network} config package:
  #   mina-generic  ->  mina-${profile}-profile  ->  mina-${network}
  # Devnet/Mainnet carry the "-profile" suffix; Lightnet and Dev do not
  # (mina-lightnet, mina-dev). breaks_pkgs supersedes the legacy monolithic
  # mina-${profile} package, but only where that name differs from the package
  # we are building (avoids a self-conflict for the lightnet/dev names).
  local package_name
  local breaks_pkgs
  case "${profile}" in
    devnet|mainnet)
      package_name="mina-${profile}-profile"
      breaks_pkgs="mina-${profile} (<< ${MINA_DEB_VERSION})"
      ;;
    lightnet|dev)
      package_name="mina-${profile}"
      breaks_pkgs=""
      ;;
    *)
      printf "Unknown profile %s provided for profile deb\n" "${profile}" >&2
      exit 1
      ;;
  esac

  echo "--- Building package ${package_name}"
  echo "build_profile_deb inputs:"
  echo "Profile Name: ${1} (like mainnet, devnet, lightnet, dev)"

  # The profile package ships only the PROFILE hint file; the actual daemon
  # binaries live in the network-free mina-generic package. The profile
  # package has no apt dependency on generic — the tent metapackage
  # (mina-${network}) is responsible for pulling all three layers together.
  create_control_file "${package_name}" "" \
    "Mina profile for network ${profile}" "" "${breaks_pkgs}"

  # Store node config hint (based on DUNE_PROFILE)
  mkdir -p "${BUILDDIR}/etc/coda/build_config"
  printf '%s' "${profile}" > "${BUILDDIR}/etc/coda/build_config/PROFILE"

  build_deb "${package_name}"
}
## END PACKAGE ##

## PROFILE-GENERIC TENT PACKAGE ##

#
# Builds mina-${PROFILE}-generic convenience tent for Devnet/Mainnet profiles.
# Lightnet and Dev don't use this — they ship directly as mina-${profile}.
#
# This is an empty metapackage that depends on mina-generic (the daemon
# binaries) and mina-${PROFILE}-profile (the PROFILE hint file), so that
# `apt-get install mina-devnet-generic` pulls in a working daemon with the
# correct profile baked in. It Replaces the old mina-${PROFILE} monolithic
# package.
#
build_profile_generic_tent_deb() {

  local profile="$1"

  echo "--- Building ${profile}-generic tent metapackage:"

  local package_name="mina-${profile}-generic"

  local depends="mina-generic (>= ${MINA_DEB_VERSION}), mina-${profile}-profile (>= ${MINA_DEB_VERSION})"

  create_control_file "${package_name}" "${depends}" \
    "Mina Protocol metapackage for ${profile} (installs generic and profile packages)" \
    "" "mina-${profile} (<< ${MINA_DEB_VERSION})"

  build_deb "${package_name}"
}
## END PROFILE-GENERIC TENT PACKAGE ##

## CONFIG PACKAGE ##
build_daemon_config_deb() {

  local network="$1"

  echo "--- Building ${network} config deb without keys:"

  local package_name="mina-${network}-config"

  # Config package contains only architecture-independent configuration data
  # (no binaries), so we build it with Architecture: all to make it usable on
  # all supported architectures.

  # Save and override architecture to "all" for the config package; restore
  # the original architecture after building the package.
  local saved_arch="${ARCHITECTURE}"
  ARCHITECTURE=all

  create_control_file "${package_name}" "" \
     "Mina Protocol Config for daemons running under ${network}" "" "mina-${network} (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_configs "${network}"

  # The config package owns mina.service so that exactly one co-installed
  # package ships it, with the correct per-network seed peer URL.
  install_mina_service "${network}"

  build_deb "${package_name}"
  ARCHITECTURE="${saved_arch}"
}
## END CONFIG PACKAGE ##

## PREFORK PACKAGE ##

# For automode purpose. We need to control location for both runtimes
CURRENT_CODENAME=berkeley
POSTFORK_CODENAME=mesa
AUTOMODE_CURRENT_DIR="${BUILDDIR}/usr/lib/mina/${CURRENT_CODENAME}"
AUTOMODE_POSTFORK_DIR="${BUILDDIR}/usr/lib/mina/${POSTFORK_CODENAME}"

#
# Builds mina-NETWORK-prefork-POSTFORK_CODENAME tailored package for automode package
#
# Output: mina-${NETWORK}-prefork-${POSTFORK_CODENAME}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Contains only the legacy binaries placed in "$AUTOMODE_CURRENT_DIR" without
# configuration files or genesis ledgers.
#

build_daemon_prefork_deb() {

  local network="$1"

  echo "--- Building mainnet berkeley deb for prefork automode :"

  local package_name="mina-${network}-prefork-${POSTFORK_CODENAME}"


  create_control_file "${package_name}" "${SHARED_DEPS}${DAEMON_DEPS}" \
    "Mina Protocol Client and Daemon for prefork under network ${network}" "${SUGGESTED_DEPS}"

  copy_common_daemon_apps "$AUTOMODE_CURRENT_DIR"

  build_deb "${package_name}"
}
## END PREFORK PACKAGE ##

# Function to DRY creating symlinks for shared apps in deb packages
# for automode runtimes that share the same dispatcher but different runtimes
create_symlinks_for_shared_apps() {
  local NETWORK_NAME=${1}

  # The dispatcher resolves the hardfork activation marker from
  # auto-fork-${MINA_NETWORK}-${MINA_PROFILE}, so MINA_PROFILE must be the
  # deployment profile of this network (devnet/mainnet), NOT the build-time
  # DUNE_PROFILE (which is "dev" for the regular build and would never match the
  # devnet/mainnet activation markers).
  local dispatch_profile
  case "${NETWORK_NAME}" in
    mainnet)
      dispatch_profile="mainnet"
      ;;
    # mesa is a devnet-signature hardfork network; it deploys with the devnet
    # profile (see Profiles.fromNetwork in buildkite Dhall and
    # dispatcher-tests.sh), so the activation marker is auto-fork-mesa-devnet.
    # mesa-mut is the mutable, devnet-signature variant of mesa: it shares
    # mesa's runtime identity (same /usr/lib/mina/mesa runtime dir,
    # MINA_NETWORK=mesa and devnet dispatch profile), so it resolves the same
    # auto-fork-mesa-devnet marker.
    devnet|mesa|mesa-mut)
      dispatch_profile="devnet"
      ;;
    *)
      echo "Not supported network name provided for post fork deb: ${NETWORK_NAME}"; exit 1
      ;;
  esac

  mkdir -p "${BUILDDIR}/usr/local/bin"

  cp ../scripts/hardfork/dispatcher.sh \
    "${BUILDDIR}/usr/local/bin/mina-dispatch"

  mkdir -p "${BUILDDIR}/etc/default"

  #Create env vars for the dispatcher
  # MINA_NETWORK is hardcoded as ocaml generation code in mina_run.ml
    cat << EOF > "${BUILDDIR}/etc/default/mina-dispatch"
MINA_NETWORK=mesa
MINA_PROFILE=${dispatch_profile}
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

  ln -sf "${AUTOMODE_CURRENT_DIR}/mina" mina-berkeley
  ln -sf "${AUTOMODE_POSTFORK_DIR}/mina" mina-mesa

  # Create directory for legacy binaries symlink if needed
  mkdir -p "${BUILDDIR}/usr/lib/mina/berkeley"
  ln -sf ../../lib/mina/berkeley/mina-create-genesis "${BUILDDIR}/usr/local/bin/mina-create-legacy-genesis"

  echo "Created symlinks in ${BUILDDIR}/usr/local/bin:"
  find "${BUILDDIR}/usr/local/bin/" -type l -exec ls -la {} \;

}

# Copies common binaries and configuration for postfork automode packages
# Includes only binaries without configuration files or genesisledgers
# Places binaries in /usr/lib/mina/<network_name> directory
copy_common_daemon_post_automode_apps_and_configs() {

  local prefork_network="${1}"

  echo "copy_common_daemon_post_automode_configs inputs:"
  echo "Network Name: ${prefork_network} (like mainnet, devnet, berkeley)"

  # Copy binaries to separate directory as we need both berkeley and mesa binaries for automode packages
  # and they share the same dispatcher and some common apps,
  mkdir -p "${AUTOMODE_POSTFORK_DIR}"
  copy_common_daemon_apps "${AUTOMODE_POSTFORK_DIR}"

  # Create symlinks for shared apps in the main bin directory that
  # dispatch to the correct runtime based on env var set in /etc/default/mina-dispatch
  create_symlinks_for_shared_apps "${prefork_network}"

  # Config files (config_<hash>.json, <network>.json) are provided by the
  # mina-<network>-config package, so we do NOT ship them here to avoid
  # dpkg file conflicts.  Only ship the prefork config when it differs from
  # the postfork hash, since the config package won't contain it.
  if [[ -n "${PREFORK_LEGACY_VERSION:-}" ]]; then
    local prefork_short_hash="${PREFORK_LEGACY_VERSION##*-}"
    local prefork_githash_config
    prefork_githash_config=$(git rev-parse --short=8 "$prefork_short_hash" 2>/dev/null || echo "")
    if [[ -n "$prefork_githash_config" ]]; then
      if [[ "$prefork_githash_config" == "$GITHASH_CONFIG" ]]; then
        echo "Prefork githash (${prefork_githash_config}) is the same as postfork; skipping config copy."
      else
        echo "Copying config for prefork daemon as config_${prefork_githash_config}.json"
        mkdir -p "${BUILDDIR}/var/lib/coda"
        cp "../genesis_ledgers/${prefork_network}.json" \
           "${BUILDDIR}/var/lib/coda/config_${prefork_githash_config}.json"
      fi
    else
      echo "WARNING: Could not resolve prefork commit hash from '${prefork_short_hash}'. Prefork config not shipped."
    fi
  fi

  # Generate bash completion for the postfork runtime. mina.service is shipped
  # by the mina-<network>-config package, not here, to avoid dpkg conflicts.
  copy_common_daemon_utils "${AUTOMODE_POSTFORK_DIR}/mina"

}


## POSTFORK PACKAGE ##

build_daemon_postfork_deb() {
  local network="$1"
  local package_name="mina-${network}-postfork-${POSTFORK_CODENAME}"


  echo "--- Building ${network} postfork deb for hardfork automode:"

  # The postfork runtime ships /etc/bash_completion.d/mina (and shares the
  # /usr/local/bin/mina dispatcher), which also lives in the network-free
  # mina-generic package. Declare Replaces/Breaks on mina-generic so the two are
  # mutually exclusive and the automode<->generic transition resolves cleanly
  # instead of failing with a dpkg "trying to overwrite" file conflict.
  create_control_file "$package_name" "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Mina Protocol Client and Daemon' "${SUGGESTED_DEPS}" "mina-generic"

  copy_common_daemon_post_automode_apps_and_configs "${network}"

  build_deb "$package_name"

}

## AUTOMODE METAPACKAGE ##

#
# Builds mina-NETWORK-automode transitional metapackage
#
# Output: mina-${NETWORK}-automode_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
#
# This is an empty metapackage that depends on both prefork and postfork
# automode packages. It Conflicts/Replaces mina-${NETWORK} (the legacy
# monolithic package) AND mina-generic (the daemon-binary package in
# the split layout, which owns /usr/local/bin/mina) so that running
# `apt-get install mina-${NETWORK}-automode` removes whichever normal daemon is
# present and pulls in both automode runtimes — and, symmetrically, so that
# reinstalling mina-generic later removes the automode metapackage.
# Provides mina-${NETWORK} for anything still depending on the legacy name.
#
# It also depends on mina-${NETWORK}-config: in the split layout that package
# owns mina.service (and the genesis config), which the prefork/postfork runtime
# packages no longer ship, so the dependency keeps a standalone
# `apt-get install mina-${NETWORK}-automode` self-sufficient — matching the old
# monolithic mina-${NETWORK}, which depended on the config package too.
#

build_daemon_automode_deb() {

  local network="$1"

  echo "--- Building ${network} automode transitional metapackage:"

  local package_name="mina-${network}-automode"

  local prefork_pkg="mina-${network}-prefork-${POSTFORK_CODENAME}"
  local postfork_pkg="mina-${network}-postfork-${POSTFORK_CODENAME}"
  local prefork_version="${PREFORK_LEGACY_VERSION:-${MINA_DEB_VERSION}}"
  local depends="${postfork_pkg} (>= ${MINA_DEB_VERSION}), ${prefork_pkg} (>= ${prefork_version}), mina-${network}-config (>= ${MINA_DEB_VERSION})"

  create_control_file "${package_name}" "${depends}" \
    "Transitional metapackage for Mina ${network} automode (installs both prefork and postfork runtimes)" \
    "" "mina-${network}, mina-generic" "mina-${network}" \
    "mina-${network}, mina-generic"

  build_deb "${package_name}"
}
## END AUTOMODE METAPACKAGE ##

## TENT METAPACKAGE ##

#
# Builds mina-NETWORK transitional metapackage (tent package)
#
# Output: mina-${NETWORK}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
#
# The old monolithic mina-${NETWORK} is now split into three layers:
#   mina-generic (binaries) + mina-${NETWORK}-profile (profile) + mina-${NETWORK}-config
# This empty tent metapackage carries the legacy name and depends on all three,
# so `apt-get install mina-${NETWORK}` still pulls in a working daemon.
# It Conflicts with mina-${NETWORK}-automode (hardfork) since they are mutually
# exclusive, and Replaces mina-${NETWORK} (<< V) to cleanly take over from
# the old monolithic package.
#
build_daemon_tent_deb() {

  local network="$1"

  echo "--- Building ${network} tent metapackage:"

  local package_name="mina-${network}"

  # network-to-profile is 1:1 for the main networks (devnet, mainnet)
  local profile="${network}"

  local depends="mina-${profile}-generic (>= ${MINA_DEB_VERSION}), mina-${network}-config (>= ${MINA_DEB_VERSION})"

  create_control_file "${package_name}" "${depends}" \
    "Mina Protocol metapackage for ${network} (installs generic, profile and config packages)" \
    "" "" "" \
    "mina-${network}-automode"

  build_deb "${package_name}"
}
## END TENT METAPACKAGE ##

## GENERIC PACKAGE ##

#
# Builds Generic daemon package with no profile nor network awareness.
#
# Output: ${MINA_GENERIC_DEB_NAME}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Where MINA_GENERIC_DEB_NAME can be:
#   - "mina-generic" (default)
#
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Generic daemon without specified signatures or configs (like ledgers etc.).
#
build_daemon_generic_deb() {

  echo "--- Building Mina Generic package"

  local _suffix="${DEB_SUFFIX#-}"
  MINA_GENERIC_DEB_NAME="mina-generic${_suffix:+-${_suffix}}"

  # A flavored generic (mina-generic-instrumented, mina-generic-lightnet) must
  # satisfy the flavor-neutral "mina-generic" dependency declared by the profile
  # packages, so it provides that virtual name at the same version. The plain
  # "mina-generic" build needs no Provides (it already carries that name).
  local provides=""
  if [ "${MINA_GENERIC_DEB_NAME}" != "mina-generic" ]; then
    provides="mina-generic (= ${MINA_DEB_VERSION})"
  fi

  create_control_file "${MINA_GENERIC_DEB_NAME}" "${SHARED_DEPS}${DAEMON_DEPS}" \
    "Mina Protocol Client and Daemon for the Generic usage" \
    "${SUGGESTED_DEPS}" "" "${provides}"

  copy_common_daemon_apps

  copy_common_daemon_utils

  build_deb "${MINA_GENERIC_DEB_NAME}"

}

## END MAINNET GENERIC PACKAGE ##

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


## HARDFORK PACKAGE ##

#
# Builds mina-${NETWORK}-config package for specified network with hardfork configuration
#
# Output: mina-${NETWORK}-config_${MINA_DEB_VERSION}_all.deb
#
# Config only package with hardfork-specific runtime config and ledgers.
# Requires RUNTIME_CONFIG_JSON and LEDGER_TARBALLS environment variables.
#
build_daemon_hardfork_config_deb() {

  local network="$1"
  local package_name="mina-${network}-config"

  echo "--- Building hardfork config for ${network} network deb without keys:"

  # Config package contains only architecture-independent configuration data
  # (no binaries), so we build it with Architecture: all to make it usable on
  # all supported architectures.

  # Save and override architecture to "all" for the hardfork config package; restore
  # the original architecture after building the package.
  local saved_arch="${ARCHITECTURE}"
  ARCHITECTURE=all

  create_control_file "${package_name}" "" \
    "Mina Protocol hardfork config for the ${network} Network" "" "mina-${network} (<< ${MINA_DEB_VERSION})"

  copy_common_daemon_hardfork_configs "${network}"

  # The hardfork config package owns mina.service, consistent with the regular
  # config package, with the correct per-network seed peer URL.
  install_mina_service "${network}"

  build_deb "${package_name}"
  ARCHITECTURE="${saved_arch}"
}

## END HARDFORK PACKAGE ##

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
  cp ./default/src/app/dump_slot_ledger/dump_slot_ledger.exe \
    "${BUILDDIR}/usr/local/bin/mina-dump-slot-ledger"

  rsync -Huav ../src/app/archive/*.sql "${BUILDDIR}/etc/mina/archive"

  build_deb "$ARCHIVE_DEB"
}

## ARCHIVE PACKAGE ##

#
# Builds mina-archive-devnet package for devnet archive node
#
# Output:
# - If network is one of mainnet: mina-archive-${NETWORK}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# - O.w. if network is devnet: mina-archive-devnet-generic${DEB_SUFFIX}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
#   Where DEB_SUFFIX can be:
#     - "" (empty, default)
#     - "-lightnet" (if DUNE_PROFILE=lightnet)
#     - "-instrumented" (if DUNE_INSTRUMENT_WITH is set)
#     - "-lightnet-instrumented" (both conditions)
# Dependencies: ${ARCHIVE_DEPS} (libssl, libgomp, libpq-dev, libjemalloc)
# Archive node package for devnet with all archive utilities and SQL scripts.
build_archive_deb () {

  local network="$1"

  local profile
  case "${network}" in
    mainnet) profile="mainnet" ;;
    devnet|mesa|mesa-mut) profile="devnet" ;;
    *) echo "Unknown network: ${network}" >&2; exit 1 ;;
  esac

  local package_name
  case "${network}" in
    mainnet)
      package_name="mina-archive-mainnet${DEB_SUFFIX}"
      ;;
    devnet)
      package_name="$MINA_ARCHIVE_DEB_NAME"
      ;;
    mesa|mesa-mut)
      package_name="mina-archive-${network}${DEB_SUFFIX}"
      ;;
  esac

  echo "--- Building archive ${network} tent metapackage"

  local depends="mina-archive-generic${DEB_SUFFIX} (>= ${MINA_DEB_VERSION}), mina-${profile}-profile (>= ${MINA_DEB_VERSION})"

  create_control_file "${package_name}" "${depends}" "Mina Archive Node for network ${network}"

  build_deb "${package_name}"

}
## END ARCHIVE PACKAGE ##


#
# Builds mina-archive-generic package for archive node. No profile nor network awareness, relies on
# generic configuration from config package and profile package.
#
# Output:
# - mina-archive-generic${DEB_SUFFIX}_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
#   Where DEB_SUFFIX can be:
#     - "" (empty, default)
#     - "-instrumented" (if DUNE_INSTRUMENT_WITH is set)
# Dependencies: ${ARCHIVE_DEPS} (libssl, libgomp, libpq-dev, libjemalloc)
# Archive node package for devnet with all archive utilities and SQL scripts.
build_archive_generic_deb () {

  local package_name="mina-archive-generic${DEB_SUFFIX}"

  echo "--- Building archive generic deb"

  create_control_file "${package_name}" "${ARCHIVE_DEPS}" "Mina Archive Node for generic usage"

  copy_common_archive_configs "${package_name}"

}
## END ARCHIVE PACKAGE ##

#
# Builds mina-delegation-verify package for delegation verification
#
# Output: mina-delegation-verify_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Utility for verifying delegation in Mina GraphQL format.
#
build_delegation_verify_deb () {
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


## CREATE PREFORK GENESIS PACKAGE ##

#
# Builds mina-create-devnet-prefork-genesis package for prefork genesis creation
#
# Output: mina-create-devnet-prefork-genesis_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Utility for creating prefork genesis ledgers for post-hardfork verification.
# Contains the runtime_genesis_ledger tool for Mina protocol.
#
build_prefork_devnet_genesis_ledger_deb() {
  echo "--- Building Mina Generic devnet create prefork genesis tool:"

  DEB_NAME="mina-create-devnet-prefork-genesis-ledger"

  create_control_file "$DEB_NAME" \
    "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Utility to verify post hardfork ledger for Mina'

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
    "${BUILDDIR}/usr/local/bin/mina-create-prefork-genesis"

  build_deb "$DEB_NAME"
}

#
# Builds mina-create-mainnet-prefork-genesis package for prefork genesis creation
#
# Output: mina-create-mainnet-prefork-genesis_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Output: mina-create-${NETWORK}-prefork-genesis_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb
# Dependencies: ${SHARED_DEPS}${DAEMON_DEPS}
#
# Utility for creating prefork genesis ledgers for postfork verification.
# Contains the runtime_genesis_ledger tool for Mina protocol.
#

build_prefork_genesis_ledger_deb() {

  local network="$1"

  echo "--- Building Mina Generic ${network} create prefork genesis tool:"

  local package_name="mina-create-${network}-prefork-genesis-ledger"

  create_control_file "$package_name" \
    "${SHARED_DEPS}${DAEMON_DEPS}" \
    'Utility to verify post hardfork ledger for Mina'

  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
    "${BUILDDIR}/usr/local/bin/mina-create-prefork-genesis"

  build_deb "$package_name"
}

## END CREATE PREFORK GENESIS PACKAGE ##


build_daemon_storage_toolbox_deb() {
  echo "--- Building Mina Berkeley daemon storage toolbox:"

  ROCKSDB_VERSION="10.5.2"
  MINA_VERSION="${GITTAG}"

  create_control_file mina-daemon-storage-toolbox \
    "${SHARED_DEPS}${DAEMON_DEPS}" \
    "Toolbox for Mina Daemon storage compatible with rocksdb in version $ROCKSDB_VERSION and mina in $MINA_VERSION"

  mkdir -p "${BUILDDIR}/usr/lib/mina/storage/$ROCKSDB_VERSION/$MINA_VERSION"
  mkdir -p "${BUILDDIR}/usr/local/bin"

  # Binaries
  cp ./default/src/app/rocksdb-scanner/rocksdb_scanner.exe \
    "${BUILDDIR}/usr/lib/mina/storage/$ROCKSDB_VERSION/$MINA_VERSION/mina-rocksdb-scanner"

  cp ../scripts/rocksdb/convert-to-legacy.sh \
    "${BUILDDIR}/usr/local/bin/mina-storage-converter"

  build_deb mina-daemon-storage-toolbox
}
