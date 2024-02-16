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

set -eo pipefail

NIX_OPTS=( --accept-flake-config --experimental-features 'nix-command flakes' )

INIT_DIR="$PWD"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [[ $# -gt 0 ]]; then
  # Branch is specified, this is a CI run
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  chown -R "${USER}" /workdir
  git config --global --add safe.directory /workdir
  git fetch
  nix-env -iA unstable.jq
  nix-env -iA unstable.curl
  nix-env -iA unstable.gnused
  nix-env -iA unstable.git-lfs
fi

if [[ ! -L compatible-devnet ]]; then
  if [[ $# == 0 ]]; then
    compatible_build=$(mktemp -d)
    git clone -b compatible --single-branch "https://github.com/MinaProtocol/mina.git" "$compatible_build"
    cd "$compatible_build"
  else
    git checkout -f $1
    git checkout -f compatible
    git checkout -f $1 -- scripts/hardfork
    compatible_build="$INIT_DIR"
  fi
  git submodule sync --recursive
  git submodule update --init --recursive
  git apply "$SCRIPT_DIR"/localnet-patches/compatible-1.patch
  nix "${NIX_OPTS[@]}" build "$compatible_build?submodules=1#devnet" --out-link "$INIT_DIR/compatible-devnet"
  git apply -R "$SCRIPT_DIR"/localnet-patches/compatible-1.patch
  if [[ $# == 0 ]]; then
    cd -
    rm -Rf "$compatible_build"
  fi
fi

if [[ $# -gt 0 ]]; then
  # Branch is specified, this is a CI run
  git checkout -f $1
  git submodule sync --recursive
  git submodule update --init --recursive
fi
git apply "$SCRIPT_DIR"/localnet-patches/berkeley-{1,2}.patch
nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet" --out-link "$INIT_DIR/fork-devnet"
git apply -R "$SCRIPT_DIR"/localnet-patches/berkeley-{1,2}.patch

"$SCRIPT_DIR"/test.sh compatible-devnet/bin/mina fork-devnet/bin/{mina,runtime_genesis_ledger} && echo "HF test completed successfully"
