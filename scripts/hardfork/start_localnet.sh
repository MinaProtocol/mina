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

if [[ ! -L berkeley2-devnet ]]; then
  berkeley2_branch="rb/berkeley2"
  if [[ $# == 0 ]]; then
    berkeley2_build=$(mktemp -d)
    git clone -b $berkeley2_branch --single-branch "https://github.com/MinaProtocol/mina.git" "$berkeley2_build"
    cd "$berkeley2_build"
  else
    git checkout -f $1
    git checkout -f $berkeley2_branch
    git checkout -f $1 -- scripts/hardfork
    berkeley2_build="$INIT_DIR"
  fi
  
  git submodule sync --recursive
  git submodule update --init --recursive
  git apply "$SCRIPT_DIR"/localnet-patches/berkeley.patch
  nix "${NIX_OPTS[@]}" build "$berkeley2_build?submodules=1#devnet" --out-link "$INIT_DIR/berkeley2-devnet"
  nix "${NIX_OPTS[@]}" build "$berkeley2_build?submodules=1#devnet.genesis" --out-link "$INIT_DIR/berkeley2-devnet"
  git apply -R "$SCRIPT_DIR"/localnet-patches/berkeley.patch
  if [[ $# == 0 ]]; then
    cd -
    rm -Rf "$berkeley2_build"
  fi
fi

if [[ $# -gt 0 ]]; then
  # Branch is specified, this is a CI run
  git checkout -f $1
  git submodule sync --recursive
  git submodule update --init --recursive
fi
git apply "$SCRIPT_DIR"/localnet-patches/berkeley.patch
nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet" --out-link "$INIT_DIR/fork-devnet"
nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet.genesis" --out-link "$INIT_DIR/fork-devnet"
git apply -R "$SCRIPT_DIR"/localnet-patches/berkeley.patch

# ./scripts/hardfork/run-localnet.sh -m fork-devnet/bin/mina -d 10 -i 30 -s 30 -c localnet/config.json --genesis-ledger-dir localnet/hf_ledgers
