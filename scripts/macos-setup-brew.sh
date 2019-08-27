#!/bin/bash
set -eu

export HOMEBREW_NO_AUTO_UPDATE=1

NEEDED_PACKAGES="gpatch opam cmake gmp pkg-config openssl libffi libsodium boost zlib libomp"
echo "Needed:  ${NEEDED_PACKAGES}"

CURRENT_PACKAGES=$(brew list | xargs)
echo "Current: ${CURRENT_PACKAGES}"

# Prune already installed packages from the todo list
for p in $CURRENT_PACKAGES; do
  NEEDED_PACKAGES=${NEEDED_PACKAGES//$p/}
done;

echo "Todo:    ${NEEDED_PACKAGES}"

# only run if there's work to do
if [[ $NEEDED_PACKAGES = *[![:space:]]* ]]; then
  yes | brew install $NEEDED_PACKAGES
else
  echo 'All required brew packages have already been installed.'
fi
