#!/bin/bash

RUNTIME_CONFIG_JSON=${RUNTIME_CONFIG_JSON:=runtime_config.json}

source scripts/deb-builder-helpers.sh

echo "------------------------------------------------------------"
echo "--- Building mainnet deb with hard-fork ledger:"

create_control_file mina-mainnet "${SHARED_DEPS}${DAEMON_DEPS}" 'Mina Protocol Client and Daemon'

# TODO(FIXME): Don't use mainnet seeds URL
copy_common_daemon_configs mainnet mainnet 'mina-seed-lists/mainnet_seeds.txt'

# Copy the overridden runtime config file to the config file location
cp "${SCRIPTPATH}/../${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"

# TODO: call "${BUILDDIR}/usr/local/bin/mina-create-genesis" here to generate the tar files

build_deb mina-mainnet-hardfork
