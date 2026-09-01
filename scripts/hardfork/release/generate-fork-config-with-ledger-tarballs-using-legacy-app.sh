#!/usr/bin/env bash

# Usage: generate-fork-config-with-ledger-tarballs-using-legacy-app.sh --exe <mina_legacy_genesis_exe> --config <fork_config> --workdir <workdir> [--ledger-name <ledger_name>] [--hash-name <hash_name>] [--prefork-genesis-config <prefork_genesis_config>]

set -e

# Default values
LEDGER_NAME="legacy_ledgers"
HASH_NAME="legacy_hashes.json"
MINA_LEGACY_GENESIS_EXE="mina-create-prefork-genesis"
PREFORK_GENESIS_CONFIG=""

TMP=$(mktemp -d)

# Parse CLI args
while [[ $# -gt 0 ]]; do
	case $1 in
		--exe)
			MINA_LEGACY_GENESIS_EXE="$2"
			shift 2
			;;
		--config)
			FORK_CONFIG="$2"
			shift 2
			;;
		--workdir)
			WORKDIR="$2"
			shift 2
			;;
		--ledger-name)
			LEDGER_NAME="$2"
			shift 2
			;;
		--hash-name)
			HASH_NAME="$2"
			shift 2
			;;
		--prefork-genesis-config)
			PREFORK_GENESIS_CONFIG="$2"
			shift 2
			;;
		*)
			echo "Unknown argument: $1" >&2
			exit 1
			;;
	esac
done

if [[ -z "$MINA_LEGACY_GENESIS_EXE" ]]; then
	echo "Missing required argument: --exe <mina_legacy_genesis_exe>" >&2
	exit 1
fi

if [[ -z "$FORK_CONFIG" ]]; then
	echo "Missing required argument: --config <fork_config>" >&2
	exit 1
fi

if [[ -z "$WORKDIR" ]]; then
	echo "Missing required argument: --workdir <workdir>" >&2
	exit 1
fi

LEDGER_PATH="$WORKDIR/$LEDGER_NAME"
HASH_PATH="$WORKDIR/$HASH_NAME"

echo "generating genesis ledgers ... (this may take a while)" >&2

# make sure files does not have genesis key
jq 'del(.genesis)' "$FORK_CONFIG" > "$TMP/fork_config_no_genesis.json"

PREFORK_GENESIS_CONFIG_ARG=""
if [[ -n "$PREFORK_GENESIS_CONFIG" ]]; then
  jq 'del(.genesis)' "$PREFORK_GENESIS_CONFIG" > "$TMP/config_no_genesis.json"
  PREFORK_GENESIS_CONFIG_ARG="--prefork-genesis-config $TMP/config_no_genesis.json"
fi

"$MINA_LEGACY_GENESIS_EXE" --pad-app-state --config-file "$TMP/fork_config_no_genesis.json" --genesis-dir "$LEDGER_PATH" --hash-output-file "$HASH_PATH" $PREFORK_GENESIS_CONFIG_ARG
