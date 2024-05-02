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

SRC_NAME="berkeley"
SRC_BRANCH=$(git symbolic-ref --short HEAD)
SRC_DEVNET="$INIT_DIR/$SRC_NAME-devnet"

DST_NAME="berkeley2"
DST_BRANCH="rb/berkeley2"
DST_DEVNET="$INIT_DIR/$DST_NAME-devnet"


echo "Building source network $SRC_NAME ..."
if [[ ! -L ${SRC_DEVNET} ]]; then
    if [[ $# -gt 0 ]]; then
        # Branch is specified, this is a CI run
        git checkout -f $1
        git submodule sync --recursive
        git submodule update --init --recursive
    fi
    git apply "$SCRIPT_DIR"/localnet-patches/berkeley.patch
    nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet" --out-link "$SRC_DEVNET"
    nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet.genesis" --out-link "$SRC_DEVNET"
    git apply -R "$SCRIPT_DIR"/localnet-patches/berkeley.patch
fi

echo "Building destination network $DST_NAME ..."
if [[ ! -L ${DST_DEVNET} ]]; then
  if [[ $# == 0 ]]; then
    dst_build=$(mktemp -d)
    git clone -b $DST_BRANCH --single-branch "https://github.com/MinaProtocol/mina.git" "$dst_build"
    cd "$dst_build"
  else
    git checkout -f $1
    git checkout -f $DST_BRANCH
    git checkout -f $1 -- scripts/hardfork
    dst_build="$INIT_DIR"
  fi
  
  git submodule sync --recursive
  git submodule update --init --recursive
  git apply "$SCRIPT_DIR"/localnet-patches/berkeley.patch
  nix "${NIX_OPTS[@]}" build "$dst_build?submodules=1#devnet" --out-link "$DST_DEVNET"
  nix "${NIX_OPTS[@]}" build "$dst_build?submodules=1#devnet.genesis" --out-link "$DST_DEVNET"
  git apply -R "$SCRIPT_DIR"/localnet-patches/berkeley.patch
  if [[ $# == 0 ]]; then
    cd -
    rm -Rf "$dst_build"
  fi
fi

SRC_TX_COUNT="30"
export SRC_TX_COUNT

echo "Running HF emergency test scenario (after $SRC_TX_COUNT transactions)"

env MAIN_SLOT=30 \
    MAIN_DELAY=20 \
    $SCRIPT_DIR/test2.sh $SRC_DEVNET{/bin/mina,-genesis/bin/runtime_genesis_ledger} $DST_DEVNET{/bin/mina,-genesis/bin/runtime_genesis_ledger}
