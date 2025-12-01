#!/usr/bin/env bash

# Usage: generate-tarballs-with-legacy-app.sh --exe <mina_legacy_genesis_exe> --config <fork_config> --workdir <workdir> --ledger-name <ledger_name> --hash-name <hash_name>

set -e

# Default values
LEDGER_NAME="legacy_ledgers"
HASH_NAME="legacy_hashes.json"

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
		*)
			echo "Unknown argument: $1" >&2
			exit 1
			;;
	esac
done

if [[ -z "$MINA_LEGACY_GENESIS_EXE" || -z "$FORK_CONFIG" || -z "$WORKDIR" ]]; then
	echo "Missing required arguments. Usage: $0 --exe <mina_legacy_genesis_exe> --config <fork_config> --workdir <workdir> [--ledger-name <ledger_name>] [--hash-name <hash_name>]" >&2
	exit 1
fi

LEDGER_PATH="$WORKDIR/$LEDGER_NAME"
HASH_PATH="$WORKDIR/$HASH_NAME"

echo "generating genesis ledgers ... (this may take a while)" >&2

"$MINA_LEGACY_GENESIS_EXE" --config-file "$FORK_CONFIG" --genesis-dir "$LEDGER_PATH" --hash-output-file "$HASH_PATH"
