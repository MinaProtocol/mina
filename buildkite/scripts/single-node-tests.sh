#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/debian/install.sh "mina-test-suite,mina-berkeley-lightnet" 1

export MINA_LIBP2P_PASS="naughty blue worm"
export MINA_PRIVKEY_PASS="naughty blue worm"

mina-command-line-tests test -v