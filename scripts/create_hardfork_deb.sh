#!/bin/bash

echo "root is ${PWD}"
echo "relative ledger dir:"
ls -lash hardfork_ledgers
echo "absolute ledger dir:"
ls -lash /workdir/hardfork_ledgers

# sourcing deb-builder-helpers.sh will change our directory, so we inputs to absolute paths first
RUNTIME_CONFIG_JSON=$(realpath -s $RUNTIME_CONFIG_JSON)
LEDGER_TARBALLS=$(realpath -s $LEDGER_TARBALLS)

# ROOT_DIR="${PWD}"
# echo "RUNNING FROM $ROOT_DIR"
# ls
# echo "----"
# echo $LEDGER_TARBALLS
# echo "----"
# realpath -s $LEDGER_TARBALLS
# echo "----"
# ls hardfork_ledgers
#
# # resolves paths from the ROOT_DIR and returns them as an absolute path
# abspath() {
#   pushd "${ROOT_DIR}" >/dev/null
#   realpath -s "$1"
#   popd >/dev/null
# }

source scripts/deb-builder-helpers.sh

echo "------------------------------------------------------------"
echo "--- Building mainnet deb with hard-fork ledger:"

create_control_file mina-mainnet-hardfork "${SHARED_DEPS}${DAEMON_DEPS}" 'Mina Protocol Client and Daemon'

# TODO(FIXME): Don't use mainnet seeds URL
copy_common_daemon_configs mainnet mainnet 'mina-seed-lists/mainnet_seeds.txt'

# Copy the overridden runtime config file to the config file location
cp "${RUNTIME_CONFIG_JSON}" "${BUILDDIR}/var/lib/coda/config_${GITHASH_CONFIG}.json"

echo "LEDGER TARBALLS: $LEDGER_TARBALLS"
for ledger_tarball in $LEDGER_TARBALLS; do
  echo "COPYING $ledger_tarball TO DEB PACKAGE"
  ls -lash /workdir/hardfork_ledgers
  cp "${ledger_tarball}" "${BUILDDIR}/var/lib/coda/"
done

build_deb mina-mainnet-hardfork
