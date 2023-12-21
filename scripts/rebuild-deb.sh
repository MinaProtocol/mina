#!/bin/bash

# Script collects binaries and keys and builds deb archives.

echo "--- Setting up the envrionment to build debian packages..."

set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../_build"

GITHASH=$(git rev-parse --short=7 HEAD)
GITHASH_CONFIG=$(git rev-parse --short=8 --verify HEAD)

set +u
BUILD_NUM=${BUILDKITE_BUILD_NUM}
BUILD_URL=${BUILDKITE_BUILD_URL}
set -u

# Load in env vars for githash/branch/etc.
source "${SCRIPTPATH}/../buildkite/scripts/export-git-env-vars.sh"

cd "${SCRIPTPATH}/../_build"

# Set dependencies based on debian release
SHARED_DEPS="libssl1.1, libgmp10, libgomp1, tzdata"

TEST_EXECUTIVE_DEPS=", mina-logproc, python3, nodejs, yarn, google-cloud-sdk, kubectl, google-cloud-sdk-gke-gcloud-auth-plugin, terraform, helm"

case "${MINA_DEB_CODENAME}" in
  bookworm|jammy)
    DAEMON_DEPS=", libffi8, libjemalloc2, libpq-dev, libprocps8, mina-logproc"
    ;;
  bullseye|focal)
    DAEMON_DEPS=", libffi7, libjemalloc2, libpq-dev, libprocps8, mina-logproc"
    ;;
  buster)
    DAEMON_DEPS=", libffi6, libjemalloc2, libpq-dev, libprocps7, mina-logproc"
    ;;
  stretch|bionic)
    DAEMON_DEPS=", libffi6, libjemalloc1, libpq-dev, libprocps6, mina-logproc"
    ;;
  *)
    echo "Unknown Debian codename provided: ${MINA_DEB_CODENAME}"; exit 1
    ;;
esac

case "${DUNE_PROFILE}" in
  devnet)
    MINA_DEB_NAME="mina-berkeley"
    ;;
  *)
    MINA_DEB_NAME="mina-berkeley-${DUNE_PROFILE}"
    ;;
esac

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
Vendor: none
Architecture: amd64
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
  fakeroot dpkg-deb --build "${BUILDDIR}" ${1}_${MINA_DEB_VERSION}.deb
  echo "build_deb outputs:"
  ls -lh ${1}_*.deb
  echo "deleting BUILDDIR ${BUILDDIR}"
  rm -rf "${BUILDDIR}"

  echo "--- Built ${1}_${MINA_DEB_VERSION}.deb"
}

# Function to DRY copying config files into daemon packages
copy_common_daemon_configs() {

  echo "------------------------------------------------------------"
  echo "copy_common_daemon_configs inputs:"
  echo "Network Name: ${1} (like mainnet, devnet, berkeley)"
  echo "Signature Type: ${2} (mainnet or testnet)"
  echo "Seed List URL path: ${3} (like seed-lists/berkeley_seeds.txt)"

  # Copy shared binaries
  cp ../src/app/libp2p_helper/result/bin/libp2p_helper "${BUILDDIR}/usr/local/bin/coda-libp2p_helper"
  # cp ./default/src/app/logproc/logproc.exe "${BUILDDIR}/usr/local/bin/mina-logproc"
  cp ./default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe "${BUILDDIR}/usr/local/bin/mina-create-genesis"
  cp ./default/src/app/generate_keypair/generate_keypair.exe "${BUILDDIR}/usr/local/bin/mina-generate-keypair"
  cp ./default/src/app/validate_keypair/validate_keypair.exe "${BUILDDIR}/usr/local/bin/mina-validate-keypair"

  # Copy signature-based Binaries (based on signature type $2 passed into the function)
  cp ./default/src/app/cli/src/mina_${2}_signatures.exe "${BUILDDIR}/usr/local/bin/mina"
  
  # Copy rosetta-based Binaries 
  cp ./default/src/app/rosetta/rosetta_${2}_signatures.exe "${BUILDDIR}/usr/local/bin/mina-rosetta"
  cp ./default/src/app/rosetta/ocaml-signer/signer_${2}_signatures.exe "${BUILDDIR}/usr/local/bin/mina-ocaml-signer"
 
  mkdir -p "${BUILDDIR}/etc/mina/rosetta"
  mkdir -p "${BUILDDIR}/etc/mina/rosetta/rosetta-cli-config"
  mkdir -p "${BUILDDIR}/etc/mina/rosetta/archive"
  mkdir -p "${BUILDDIR}/etc/mina/rosetta/genesis_ledgers"

  # --- Copy artifacts
  cp ../src/app/rosetta/*.conf "${BUILDDIR}/etc/mina/rosetta"
  cp ../src/app/rosetta/*.sh "${BUILDDIR}/etc/mina/rosetta"

  cp ../src/app/rosetta/rosetta-cli-config/*.json "${BUILDDIR}/etc/mina/rosetta/rosetta-cli-config"
  cp ../src/app/rosetta/rosetta-cli-config/*.ros "${BUILDDIR}/etc/mina/rosetta/rosetta-cli-config"
  cp ../src/app/archive/*.sql "${BUILDDIR}/etc/mina/rosetta/archive"
  cp -r ../genesis_ledgers/* ${BUILDDIR}/etc/mina/rosetta/genesis_ledgers/

  # Copy over Build Configs (based on $2)
  mkdir -p "${BUILDDIR}/etc/coda/build_config"
  # Use parameter expansion to either return "mainnet.mlh" or "devnet.mlh"
  cp "../src/config/${2//test/dev}.mlh" "${BUILDDIR}/etc/coda/build_config/BUILD.mlh"
  rsync -Huav ../src/config/* "${BUILDDIR}/etc/coda/build_config/."

  mkdir -p "${BUILDDIR}/var/lib/coda"

  # Include all useful genesis ledgers
  cp ../genesis_ledgers/mainnet.json "${BUILDDIR}/var/lib/coda/mainnet.json"
  cp ../genesis_ledgers/devnet.json "${BUILDDIR}/var/lib/coda/devnet.json"
  cp ../genesis_ledgers/berkeley.json "${BUILDDIR}/var/lib/coda/berkeley.json"
  # Set the default configuration based on Network name ($1)
  cp ../genesis_ledgers/${1}.json "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"

  # Update the mina.service with a new default PEERS_URL based on Seed List URL $3
  mkdir -p "${BUILDDIR}/usr/lib/systemd/user/"
  sed "s%PEERS_LIST_URL_PLACEHOLDER%https://storage.googleapis.com/${3}%" ../scripts/mina.service > "${BUILDDIR}/usr/lib/systemd/user/mina.service"

  # Copy the genesis ledgers and proofs as these are fairly small and very valuable to have
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
  env COMMAND_OUTPUT_INSTALLATION_BASH=1 "${BUILDDIR}/usr/local/bin/mina" > "${BUILDDIR}/etc/bash_completion.d/mina"

}

##################################### GENERATE KEYPAIR PACKAGE #######################################
if ${MINA_BUILD_MAINNET} # only builds on mainnet-like branches
then

  echo "------------------------------------------------------------"
  echo "--- Building generate keypair deb:"

  create_control_file mina-generate-keypair "${SHARED_DEPS}" 'Utility to regenerate mina private public keys in new format'

  # Binaries
  cp ./default/src/app/generate_keypair/generate_keypair.exe "${BUILDDIR}/usr/local/bin/mina-generate-keypair"
  cp ./default/src/app/validate_keypair/validate_keypair.exe "${BUILDDIR}/usr/local/bin/mina-validate-keypair"

  build_deb mina-generate-keypair

fi # only builds on mainnet-like branches
##################################### END GENERATE KEYPAIR PACKAGE #######################################


##################################### LOGPROC PACKAGE #######################################

create_control_file mina-logproc "${SHARED_DEPS}" 'Utility for processing mina-daemon log output'

# Binaries
cp ./default/src/app/logproc/logproc.exe "${BUILDDIR}/usr/local/bin/mina-logproc"

build_deb mina-logproc

##################################### END LOGPROC PACKAGE #######################################


##################################### GENERATE TEST_EXECUTIVE PACKAGE #######################################

create_control_file mina-test-executive "${SHARED_DEPS}${TEST_EXECUTIVE_DEPS}" 'Tool to run automated tests against a full mina testnet with multiple nodes.'

# Binaries
cp ./default/src/app/test_executive/test_executive.exe "${BUILDDIR}/usr/local/bin/mina-test-executive"

build_deb mina-test-executive

##################################### GENERATE BATCH TXN TOOL PACKAGE #######################################

create_control_file mina-batch-txn "${SHARED_DEPS}" 'Load transaction tool against a mina node.'

# Binaries
cp ./default/src/app/batch_txn_tool/batch_txn_tool.exe "${BUILDDIR}/usr/local/bin/mina-batch-txn"

build_deb mina-batch-txn

##################################### END BATCH TXN TOOL PACKAGE #######################################

##################################### GENERATE TEST SUITE PACKAGE #######################################


create_control_file mina-test-suite "${SHARED_DEPS}" 'Test suite apps for mina.'

# Binaries
cp ./default/src/test/command_line_tests/command_line_tests.exe "${BUILDDIR}/usr/local/bin/mina-command-line-tests"

build_deb mina-test-suite

##################################### END TEST SUITE PACKAGE #######################################

##################################### MAINNET PACKAGE #######################################
if ${MINA_BUILD_MAINNET} # only builds on mainnet-like branches
then

  echo "------------------------------------------------------------"
  echo "--- Building mainnet deb without keys:"

  create_control_file mina-mainnet "${SHARED_DEPS}${DAEMON_DEPS}" 'Mina Protocol Client and Daemon'

  copy_common_daemon_configs mainnet mainnet 'mina-seed-lists/mainnet_seeds.txt'

  build_deb mina-mainnet

fi # only builds on mainnet-like branches
##################################### END MAINNET PACKAGE #######################################

##################################### DEVNET PACKAGE #######################################
if ${MINA_BUILD_MAINNET} # only builds on mainnet-like branches
then

  echo "------------------------------------------------------------"
  echo "--- Building testnet signatures deb without keys:"

  copy_control_file mina-devnet "${SHARED_DEPS}${DAEMON_DEPS}" 'Mina Protocol Client and Daemon for the Devnet Network'

  copy_common_daemon_configs devnet testnet 'seed-lists/devnet_seeds.txt'

  build_deb mina-devnet

fi # only builds on mainnet-like branches
##################################### END DEVNET PACKAGE #######################################

##################################### ZKAPP TEST TXN #######################################
echo "------------------------------------------------------------"
echo "--- Building Mina Berkeley ZkApp test transaction tool:"

create_control_file mina-zkapp-test-transaction "${SHARED_DEPS}${DAEMON_DEPS}" 'Utility to generate ZkApp transactions in Mina GraphQL format'

# Binaries
cp ./default/src/app/zkapp_test_transaction/zkapp_test_transaction.exe "${BUILDDIR}/usr/local/bin/mina-zkapp-test-transaction"

build_deb mina-zkapp-test-transaction

##################################### END ZKAPP TEST TXN PACKAGE #######################################

##################################### BERKELEY PACKAGE #######################################
echo "------------------------------------------------------------"
echo "--- Building Mina Berkeley testnet signatures deb without keys:"

mkdir -p "${BUILDDIR}/DEBIAN"
create_control_file "${MINA_DEB_NAME}" "${SHARED_DEPS}${DAEMON_DEPS}" 'Mina Protocol Client and Daemon'

copy_common_daemon_configs berkeley testnet 'seed-lists/berkeley_seeds.txt'

build_deb "${MINA_DEB_NAME}"

##################################### END BERKELEY PACKAGE #######################################

# TODO: Find a way to package keys properly without blocking/locking in CI
# TODO: Keys should be their own package, which this 'non-noprovingkeys' deb depends on
# For now, deleting keys in /tmp/ so that the complicated logic below for moving them short-circuits and both packages are built without keys
rm -rf /tmp/s3_cache_dir /tmp/coda_cache_dir

# Keys
# Identify actual keys used in build
# NOTE: Moving the keys from /tmp because of storage constraints. This is OK
# because building deb is the last step and therefore keys, genesis ledger, and
# proof are not required in /tmp
echo "Checking PV keys"
mkdir -p "${BUILDDIR}/var/lib/coda"
compile_keys=("step" "vk-step" "wrap" "vk-wrap")
for key in ${compile_keys[*]}
do
    echo -n "Looking for keys matching: ${key} -- "

    # Awkward, you can't do a filetest on a wildcard - use loops
    for f in  /tmp/s3_cache_dir/${key}*; do
        if [ -e "$f" ]; then
            echo " [OK] found key in s3 key set"
            mv /tmp/s3_cache_dir/${key}* "${BUILDDIR}/var/lib/coda/."
            break
        fi
    done

    for f in  /var/lib/coda/${key}*; do
        if [ -e "$f" ]; then
            echo " [OK] found key in stable key set"
            mv /var/lib/coda/${key}* "${BUILDDIR}/var/lib/coda/."
            break
        fi
    done

    for f in  /tmp/coda_cache_dir/${key}*; do
        if [ -e "$f" ]; then
            echo " [WARN] found key in compile-time set"
            mv /tmp/coda_cache_dir/${key}* "${BUILDDIR}/var/lib/coda/."
            break
        fi
    done
done

# Build mina block producer sidecar
if ${MINA_BUILD_MAINNET} # only builds on mainnet-like branches
then
  ../automation/services/mina-bp-stats/sidecar/build.sh # only builds on mainnet-like branches
  rm -rf "${BUILDDIR}"
fi

if ${MINA_BUILD_MAINNET} # only builds on mainnet-like branches
then
  echo "---- Built all packages including mainnet, devnet, and the sidecar"
else
  echo "---- Not a mainnet-like branch, only built berkeley and beyond packages"  
fi

ls -lh mina*.deb
