#!/usr/bin/env bash

set -euox pipefail

# This script runs the archive hardfork toolbox tests.
# It assumes that the archive hardfork toolbox has already been built.
# It requires the archive database URI to be provided via --postgres-uri argument.

# Parse command line arguments
POSTGRES_URI="${PG_CONN:-}"
TOOLBOX_PATH="mina-archive-hardfork-toolbox"
AVAILABLE_MODES=("pre-fork" "post-fork" "upgrade")
MODE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --postgres-uri)
            POSTGRES_URI="$2"
            shift 2
            ;;
        --toolbox-path)
            TOOLBOX_PATH="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            if [[ ! " ${AVAILABLE_MODES[*]} " =~ ${MODE} ]]; then
                echo "Invalid mode: $MODE"
                echo "Available modes are: ${AVAILABLE_MODES[*]}"
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --postgres-uri <database_uri> [--toolbox-path <path_to_binary>]"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$POSTGRES_URI" ]]; then
    echo "Error: --postgres-uri argument is required"
    echo "Usage: $0 --postgres-uri <database_uri> [--toolbox-path <path_to_binary>]"
    exit 1
fi

echo "Using archive database URI: $POSTGRES_URI"
echo "Using toolbox binary: $TOOLBOX_PATH"

# Run the archive hardfork toolbox tests
echo "Running archive hardfork toolbox tests..."

# Define test parameters
# Those values are hardcoded for the purpose of testing the toolbox.
# They correspond sql scripts scripts/tests/archive-hardfork-toolbox/*.sql
# Reason for using two databases is to simulate pre-fork and post-fork states independently.
# This is required as for example pre-fork db cannot include transactions after stop slot.
# Such check will fail if we try to run it on a single db including both pre and post fork data.

# Pre-fork test parameters

FORK_CANDIDATE_HEIGHT=297884
FORK_CANDIDATE_GENESIS_SLOT=448610
FORK_CANDIDATE_STATE_HASH="3NKJ8d6ncwhLGv3B28xCuTQfXxa3MyEShSWasVFYjtnm8sFZrhF6"
LATEST_STATE_HASH="3NKX1QQ5bSjPwE5HLxLZ6dj2Abe9uk4tqWsjGisxittxLEd8rrLK"

# Post-fork test parameters
# these values correspond to the fork defined in scripts/tests/archive-hardfork-toolbox/hf_archive.tar.gz
# that data can be different from the pre-fork test data. They are independent tests.
FORK_SLOT=1067
FORK_STATE_HASH="3NK38gNjWR6sE2MTKV8AqogjY6WaboPjSDq3zfpfVtiUgLMze1Wm"

if [[ "$MODE" == "pre-fork" ]]; then
    "$TOOLBOX_PATH" fork-candidate is-in-best-chain --postgres-uri "$POSTGRES_URI" --fork-state-hash "$FORK_CANDIDATE_STATE_HASH" --fork-height "$FORK_CANDIDATE_HEIGHT" --fork-slot "$FORK_CANDIDATE_GENESIS_SLOT"

    "$TOOLBOX_PATH" fork-candidate confirmations --postgres-uri "$POSTGRES_URI" --latest-state-hash "$LATEST_STATE_HASH" --fork-slot "$FORK_CANDIDATE_GENESIS_SLOT" --required-confirmations 1

    "$TOOLBOX_PATH" fork-candidate no-commands-after --postgres-uri "$POSTGRES_URI" --fork-state-hash "$FORK_CANDIDATE_STATE_HASH" --fork-slot "$FORK_CANDIDATE_GENESIS_SLOT"
fi

if [[ "$MODE" == "upgrade" ]]; then
    "$TOOLBOX_PATH" verify-upgrade --postgres-uri "$POSTGRES_URI" --version 4.0.0
fi

if [[ "$MODE" == "post-fork" ]]; then
    "$TOOLBOX_PATH" validate-fork --postgres-uri "$POSTGRES_URI" --fork-slot "$FORK_SLOT" --fork-state-hash "$FORK_STATE_HASH"
fi