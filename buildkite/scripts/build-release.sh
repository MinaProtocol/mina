#!/bin/bash

set -eo pipefail

source "./buildkite/scripts/export-git-env-vars.sh"

([ -z ${DUNE_PROFILE+x} ] || [ -z ${MINA_DEB_CODENAME+x} ]) && echo "required env vars were not provided" && exit 1

source ~/.profile

echo "--- Bundle all packages for Debian ${MINA_DEB_CODENAME}"
./buildkite/scripts/build-artifact.sh

echo " Includes mina daemon, archive-node, rosetta, generate keypair for devnet"
[[ ${MINA_BUILD_MAINNET} ]] && echo " MINA_BUILD_MAINNET is true so this includes the mainnet and devnet packages for mina-daemon as well"

echo "--- Prepare debian packages"
./scripts/debian/build.sh $@

echo "--- Git diff after build is complete:"
git diff --exit-code -- .