#!/bin/bash
env
echo "CONFIG_JSON_GZ_URL=\"$CONFIG_JSON_GZ_URL\", DUNE_PROFILE=\"$DUNE_PROFILE\""

([ -z "$CONFIG_JSON_GZ_URL" ] || [ -z "$DUNE_PROFILE" ]) && echo "required env vars were not provided" && exit 1

source ~/.profile
curl -o config.json.gz $CONFIG_JSON_GZ_URL
gunzip config.json.gz
dune build --profile="$DUNE_PROFILE" src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe src/app/logproc/logproc.exe
mkdir hardfork_ledgers
_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json | tee runtime_genesis_ledger.log | _build/default/src/app/logproc/logproc.exe
# , Cmd.run '' 
#     _build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json \
#     | tee runtime_genesis_ledger.log \
#     | _build/default/src/app/logproc/logproc.exe
#     ''
FORK_CONFIG_JSON=config.json LEDGER_HASHES_JSON=hardfork_ledger_hashes.json scripts/hardfork/create_runtime_config.sh > new_config.json

# TEMP HACK -- the ledger tool builds bad symlinks, so we patch them here for now (will fix later)
rm hardfork_ledgers/*_accounts_*.tar.gz
export LEDGER_TARBALLS="$(echo hardfork_ledgers/*.tar.gz)"
# export LEDGER_TARBALLS="$(echo hardfork_ledgers/*_accounts_*.tar.gz)"
# for ledger_tarball in $LEDGER_TARBALLS; do
#   cp --remove-destination $(readlink "$ledger_tarball") "$ledger_tarball"
# done

MINA_BUILD_MAINNET=1 RUNTIME_CONFIG_JSON=new_config.json exec ./buildkite/scripts/build-hardfork-package.sh
