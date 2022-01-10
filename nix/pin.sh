#!/usr/bin/env bash
ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"/.. &> /dev/null && pwd )
nix registry add mina "git+file://$ROOT?submodules=1"
