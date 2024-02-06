#!/bin/bash

source scripts/deb-builder-helpers.sh

echo "------------------------------------------------------------"
echo "--- Building devnet deb with hard-fork ledger:"

create_control_file mina-devnet-hardfork "${SHARED_DEPS}${DAEMON_DEPS}" 'Mina Protocol Client and Daemon'

# TODO(FIXME): Don't use devnet seeds URL
copy_common_daemon_configs devnet devnet 'mina-seed-lists/devnet_seeds.txt'

# Copy the overridden runtime config file to the config file location
cp "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"

# TODO: call "${BUILDDIR}/usr/local/bin/mina-create-genesis" here to generate the tar files

build_deb mina-devnet-hardfork
