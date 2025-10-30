#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/debian/install.sh "mina-test-suite,mina-berkeley-lightnet" 1

# --- Install Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
sudo apt-get install --no-install-recommends -y nodejs=18.*
rm -rf /var/lib/apt/lists/*

# --- Copy and install mina-test-signer
npm install -g ./scripts/tests/mina-signer

export MINA_LIBP2P_PASS="naughty blue worm"
export MINA_PRIVKEY_PASS="naughty blue worm"

mina-command-line-tests test -v