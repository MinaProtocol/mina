#!/usr/bin/env bash
# Set up flake registry to get Mina with all the submodules
#
# Usage:
#   nix/pin.sh           # registers as 'mina' (default)
#   nix/pin.sh mybranch  # registers as 'mybranch' for multi-worktree use

# Find the root of the Mina repo
ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"/.. &> /dev/null && pwd )
# Update the submodules
pushd "$ROOT" && git submodule sync && git submodule update --init --recursive --depth 1 && popd
# Add the flake registry entry (accept optional name for worktree-specific registrations)
NAME="${1:-mina}"
nix registry add "$NAME" "git+file://$ROOT?submodules=1"
