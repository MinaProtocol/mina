#!/usr/bin/env bash
# Set up flake registry to get Mina with all the submodules

# Find the root of the Mina repo
ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"/.. &> /dev/null && pwd )
# Update the submodules
pushd "$ROOT" && git submodule sync && git submodule update --init --recursive && popd
# Add the flake registry entry
nix registry add mina "git+file://$ROOT?submodules=1"
