#!/bin/bash
set -eu

export HOMEBREW_NO_AUTO_UPDATE=1

# re-reads /usr/local/Homebrew if a cache has been put in place
brew update-reset

NEEDED_PACKAGES=" bash boost cmake gmp gpatch jemalloc libffi libomp libsodium opam openssl@1.1 pkg-config zlib libpq postgresql"
echo "Needed:  ${NEEDED_PACKAGES}"

CURRENT_PACKAGES=$(brew list | xargs)
echo "Current: ${CURRENT_PACKAGES}"

# Prune already installed packages from the todo list
for p in $CURRENT_PACKAGES; do
  NEEDED_PACKAGES=${NEEDED_PACKAGES// $p / }
done;

echo "Todo:    ${NEEDED_PACKAGES}"

# Remove old python (uses force to always return true)
# https://discourse.brew.sh/t/python-2-eol-2020/4647
brew uninstall --force python@2

# only run if there's work to do
if [[ $NEEDED_PACKAGES = *[![:space:]]* ]]; then
  yes | brew install $NEEDED_PACKAGES
  brew update
  # Python needs a reinstall so that it picks up openssl@1.1
  brew reinstall --force python3
else
  echo 'All required brew packages have already been installed.'
fi
