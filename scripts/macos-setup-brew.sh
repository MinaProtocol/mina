#!/bin/bash
set -eu

CURRENT_PACKAGES=$(env HOMEBREW_NO_AUTO_UPDATE=1 brew list)
NEEDED_PACKAGES="gpatch opam cmake gmp pkg-config openssl libffi libsodium boost zlib libomp"

# Prune already installed packages from the todo list
for p in $CURRENT_PACKAGES; do
  NEEDED_PACKAGES=${PACKAGES//$p/}
done;

# only run if there's work to do
if [[ $NEEDED_PACKAGES = *[![:space:]]* ]]; then
  yes | env HOMEBREW_NO_AUTO_UPDATE=1 brew install $NEEDED_PACKAGES
else
  echo 'All required brew packages have already been installed.'
fi
