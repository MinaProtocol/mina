#!/usr/bin/env bash

if [[ "$1" == "" ]]; then
  echo "specify username@sshserver as the argument for the script"
fi

ssh "$1" 'mkdir -p genesis_ledgers'
scp -C genesis_ledgers/*.json "$1":genesis_ledgers
scp -C _build/default/src/app/cli/src/mina.exe "$1":mina
scp -C src/app/libp2p_helper/result/bin/libp2p_helper "$1":helper
scp scripts/setup-nix-remote.sh "$1":setup.sh
scp shell.nix "$1":shell.nix

ssh "$1" ./setup.sh
