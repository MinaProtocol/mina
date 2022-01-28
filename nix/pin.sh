#!/usr/bin/env bash
ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"/.. &> /dev/null && pwd )
pushd "$ROOT" && git submodule sync && git submodule update --init --recursive && popd
nix registry add mina "git+file://$ROOT?submodules=1"
