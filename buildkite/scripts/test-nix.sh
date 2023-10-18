#!/bin/bash

mkdir -p "${XDG_CONFIG_HOME-${HOME}/.config}/nix"
echo 'experimental-features = nix-command flakes' > "${XDG_CONFIG_HOME-${HOME}/.config}/nix/nix.conf"

nix build mina --accept-flake-config
nix develop mina
