#!/bin/bash

# sourcing deb-builder-helpers.sh will change our directory, so we inputs to absolute paths first
RUNTIME_CONFIG_JSON=$(realpath -s $RUNTIME_CONFIG_JSON)
LEDGER_TARBALLS=$(realpath -s $LEDGER_TARBALLS)

source scripts/deb-builder-helpers.sh

echo "------------------------------------------------------------"
echo "--- Building mainnet deb with hard-fork ledger:"

create_control_file mina-mainnet-hardfork "${SHARED_DEPS}${DAEMON_DEPS}" 'Mina Protocol Client and Daemon'

# TODO(FIXME): Don't use mainnet seeds URL
copy_common_daemon_configs mainnet mainnet 'mina-seed-lists/mainnet_seeds.txt'

# Copy the overridden runtime config file to the config file location
cp "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"

for ledger_tarball in $LEDGER_TARBALLS; do
  cp "${ledger_tarball}" "${BUILDDIR}/var/lib/coda/"
done

build_deb mina-mainnet-hardfork

build_logproc_deb
build_keypair_deb
build_archive_deb
build_batch_txn_deb
build_test_executive_deb
build_test_suite_deb
build_zkapp_test_transaction_deb
