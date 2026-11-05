#!/usr/bin/env bash

# Usage: generate-fork-config-with-ledger-tarballs-using-legacy-app.sh --exe <mina_legacy_genesis_exe> --config <fork_config> --workdir <workdir> [--ledger-name <ledger_name>] [--hash-name <hash_name>]
#
# The legacy executable is the previous release's runtime_genesis_ledger, a
# Mesa-era tool (4.0.0 or later): the fork is Mesa -> Mesa and the accounts are
# loaded verbatim with --identity-conversion, as the daemon's own hardfork
# migration does. Without the flag the tool applies the Berkeley -> Mesa
# slot_reduction_update to every account still vesting at the fork slot.

set -e

# Default values
LEDGER_NAME="legacy_ledgers"
HASH_NAME="legacy_hashes.json"
MINA_LEGACY_GENESIS_EXE="mina-create-prefork-genesis"

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

# The legacy app rejects .genesis. The config is copied byte for byte: token
# symbols and zkApp URIs are arbitrary bytes, not always valid UTF-8, so no
# text-only JSON tool is used on it.
"$(dirname "$0")/remove-genesis-field.py" "$FORK_CONFIG" "$TMP/fork_config_no_genesis.json"

"$MINA_LEGACY_GENESIS_EXE" --identity-conversion --pad-app-state --config-file "$TMP/fork_config_no_genesis.json" --genesis-dir "$LEDGER_PATH" --hash-output-file "$HASH_PATH"
