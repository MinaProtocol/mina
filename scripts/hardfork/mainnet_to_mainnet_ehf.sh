#!/usr/bin/env bash

# This scripts builds compatible and current branch with nix
# It handles two cases differently:
# - When given an $1 argument, it treats itself as being run in
#   Buildkite CI and $1 to be "fork" branch that needs to be built
# - When it isn't given any arguments, it asusmes it is being
#   executed locally and builds code in $PWD as the fork branch
#
# When run locally, `compatible` branch is built in a temporary folder
# (and fetched clean from Mina's repository). When run in CI,
# `compatible` branch of git repo in $PWD is used to being the
# compatible executable.
#
# In either case at the end of its execution this script leaves
# current dir at the fork branch (in case of local run, it never
# switches the branch with git) and nix builds put to `compatible-devnet`
# and `fork-devnet` symlinks (located in $PWD).

set -exo pipefail

NIX_OPTS=( --accept-flake-config --experimental-features 'nix-command flakes' )

INIT_DIR="$PWD"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SRC_NAME="compatible"
SRC_BRANCH="compatible"
SRC_DEVNET="$INIT_DIR/$SRC_NAME-devnet"

DST_NAME="${SRC_NAME}"
DST_BRANCH="${SRC_BRANCH}"
DST_DEVNET="$INIT_DIR/$DST_NAME-devnet"


echo "Building source network $SRC_NAME ..."
if [[ ! -L ${SRC_DEVNET} ]]; then
    if [[ $# == 0 ]]; then
      src_build=$(mktemp -d)
      git clone -b $SRC_BRANCH --single-branch "https://github.com/MinaProtocol/mina.git" "$src_build"
      cd "$src_build"
    else
        git checkout -f $1
        git submodule sync --recursive
        git submodule update --init --recursive
    fi

    git apply "$SCRIPT_DIR"/localnet-patches/compatible.patch
    nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet" --out-link "$SRC_DEVNET"
    nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet.genesis" --out-link "$SRC_DEVNET"
    git apply -R "$SCRIPT_DIR"/localnet-patches/compatible.patch

    if [[ $# == 0 ]]; then
        cd -
        rm -Rf "$src_build"
    fi
fi

# Default configuration for hard fork test for compatible

# height that we need to reach to trigger hard fork
UNTIL_HEIGHT=10

# height from which we get the fork configuration 
FORK_CONFIG_HEIGHT=5

# depth of the node state we remember (should be at least UNTIL_HEIGHT - FORK_CONFIG_HEIGHT)
K=30

echo "Running compatible to compatible HF emergency test scenario at height ${UNTIL_HEIGHT} with fork config at height ${FORK_CONFIG_HEIGHT}"

env UNTIL_HEIGHT=${UNTIL_HEIGHT} K=${K} FORK_CONFIG_HEIGHT=${FORK_CONFIG_HEIGHT} $SCRIPT_DIR/test_m2m_ehf.sh $SRC_DEVNET{/bin/mina,-genesis/bin/runtime_genesis_ledger} $DST_DEVNET{/bin/mina,-genesis/bin/runtime_genesis_ledger}
