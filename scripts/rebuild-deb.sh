#!/bin/bash

# Script collects binaries and keys and builds deb archives.

source scripts/deb-builder-helpers.sh

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

##################################### GENERATE RECEIPT CHAIN HASH FIX PACKAGE #######################################

create_control_file mina-receipt-chain-hash-fix "${SHARED_DEPS}${DAEMON_DEPS}" 'Tool to run automated fix against a archive database for receipt chain hash.'

mkdir -p "${BUILDDIR}/etc/mina/receipt-chain-hash-fix-script"

# Binaries
cp ../scripts/migrate-itn-data.sh "${BUILDDIR}/etc/mina/receipt-chain-hash-fix-script/migrate-itn-data.sh"
cp ./default/src/app/last_vrf_output_to_b64/last_vrf_output_to_b64.exe "${BUILDDIR}/usr/local/bin/mina-last-vrf-output-to-b64"
cp ./default/src/app/receipt_chain_hash_to_b58/receipt_chain_hash_to_b58.exe "${BUILDDIR}/usr/local/bin/mina-receipt-chain-hash-to-b58"

build_deb mina-receipt-chain-hash-fix

##################################### END RECEIPT CHAIN HASH FIX PACKAGE #######################################

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
