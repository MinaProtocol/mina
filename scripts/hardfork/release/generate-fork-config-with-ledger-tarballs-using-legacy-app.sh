#!/usr/bin/env bash

# Usage: generate-fork-config-with-ledger-tarballs-using-legacy-app.sh.sh --exe <mina_legacy_genesis_exe> --config <fork_config> --workdir <workdir> --ledger-name <ledger_name> --hash-name <hash_name>

set -e

# Default values
LEDGER_NAME="legacy_ledgers"
HASH_NAME="legacy_hashes.json"
MINA_LEGACY_GENESIS_EXE="mina-create-legacy-genesis"
HARD_FORK_GENESIS_SLOT_DELTA=""

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
		--hard-fork-genesis-slot-delta)
			HARD_FORK_GENESIS_SLOT_DELTA="$2"
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

HARD_FORK_GENESIS_SLOT_DELTA_ARG=""
if [[ -n "$HARD_FORK_GENESIS_SLOT_DELTA" ]]; then
  HARD_FORK_GENESIS_SLOT_DELTA_ARG="--hardfork-slot $HARD_FORK_GENESIS_SLOT_DELTA"
fi

"$MINA_LEGACY_GENESIS_EXE" --pad-app-state --config-file "$FORK_CONFIG" --genesis-dir "$LEDGER_PATH" --hash-output-file "$HASH_PATH" $HARD_FORK_GENESIS_SLOT_DELTA_ARG