#!/bin/bash

([ -z ${RUNTIME_CONFIG_JSON+x} ] || [ -z ${LEDGER_TARBALLS+x} ] || [ -z ${NETWORK_NAME+x} ]) && echo "required env vars were not provided" && exit 1

# sourcing deb-builder-helpers.sh will change our directory, so we inputs to absolute paths first
RUNTIME_CONFIG_JSON=$(realpath -s $RUNTIME_CONFIG_JSON)
LEDGER_TARBALLS=$(realpath -s $LEDGER_TARBALLS)

NETWORK_TAG="mina-${NETWORK_NAME}-hardfork"

case "${NETWORK_NAME}" in 
  mainnet)
    SIGNATURE_KIND=mainnet
    SEEDS_LIST=mina-seed-lists/mainnet_seeds.txt
    CONTROL_FILE_DESCRIPTION='Mina Protocol Client and Daemon'
    BUILD_KEYPAIR_DEB=true
    ;;
  devnet)
    SIGNATURE_KIND=testnet
    SEEDS_LIST=seed-lists/devnet_seeds.txt
    CONTROL_FILE_DESCRIPTION='Mina Protocol Client and Daemon for the Devnet Network'
    BUILD_KEYPAIR_DEB=false
    ;;
  berkeley)
    SIGNATURE_KIND=testnet
    SEEDS_LIST=seed-lists/berkeley_seeds.txt
    CONTROL_FILE_DESCRIPTION='Mina Protocol Client and Daemon for the Berkeley Network'
    BUILD_KEYPAIR_DEB=false
    ;;
  *)
    echo "unrecognized network name: ${NETWORK_NAME}"
    exit 1
    ;;
esac

echo "------------------------------------------------------------"
echo "--- Building mainnet deb with hard-fork ledger:"

source scripts/deb-builder-helpers.sh

create_control_file "${NETWORK_TAG}" "${SHARED_DEPS}${DAEMON_DEPS}" "${CONTROL_FILE_DESCRIPTION}"
copy_common_daemon_configs "${NETWORK_NAME}" "${SIGNATURE_KIND}" "${SEEDS_LIST}"

# Copy the overridden runtime config file to the config file location
cp "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"
for ledger_tarball in $LEDGER_TARBALLS; do
  cp "${ledger_tarball}" "${BUILDDIR}/var/lib/coda/"
done

# Overwrite outdated ledgers that are being updated by the hardfork (backing up the outdated ledgers)
mv "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.json" "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.old.json"
cp "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/${NETWORK_NAME}.json"
mv "${BUILDDIR}/etc/mina/rosetta/genesis_ledgers/${NETWORK_NAME}.json" "${BUILDDIR}/etc/mina/rosetta/genesis_ledgers/${NETWORK_NAME}.old.json"
cp "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/etc/mina/rosetta/genesis_ledgers/${NETWORK_NAME}.json"

build_deb "${NETWORK_TAG}"
build_logproc_deb
$BUILD_KEYPAIR_DEB && MINA_BUILD_MAINNET=1 build_keypair_deb
build_archive_deb
build_batch_txn_deb
build_test_executive_deb
build_functional_test_suite_deb
build_zkapp_test_transaction_deb
