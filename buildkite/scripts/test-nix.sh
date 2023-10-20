#!/bin/sh

set -euo pipefail

set -eou pipefail
set +x

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 branch"
  exit 1
fi


mkdir -p "${XDG_CONFIG_HOME-${HOME}/.config}/nix"
echo 'experimental-features = nix-command flakes' > "${XDG_CONFIG_HOME-${HOME}/.config}/nix/nix.conf"

git config --global --add safe.directory /workdir

# Nix has issue when performing operations on detached head
# On Ci machine it spit out issues like:
# fatal: reference is not a tree: ....
# error:
#       … while fetching the input 'git+file:///workdir'
#
#       error: program 'git' failed with exit code 128
# That is why we checkout branch explicitly
git fetch
git checkout $1

./nix/pin.sh

nix build mina --accept-flake-config