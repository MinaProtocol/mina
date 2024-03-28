#!/bin/bash

set -eo pipefail

([ -z ${DUNE_PROFILE+x} ] || [ -z ${MINA_DEB_CODENAME+x} ]) && echo "required env vars were not provided" && exit 1

source ~/.profile
source ./buildkite/scripts/export-git-env-vars.sh
if [[ ${BUILDKITE_BRANCH} = "prealfaalfa" ]]; then
    export MINA_BUILD_MAINNET=true
fi
./buildkite/scripts/build-artifact.sh

echo "--- Bundle all packages for Debian ${MINA_DEB_CODENAME}"
echo " Includes mina daemon, archive-node, rosetta, generate keypair for berkeley"
[[ ${MINA_BUILD_MAINNET} ]] && echo " MINA_BUILD_MAINNET is true so this includes the mainnet and devnet packages for mina-daemon as well"


echo "--- Prepare debian packages"
./scripts/rebuild-deb.sh $@

echo "--- Upload debs to amazon s3 repo"
./buildkite/scripts/publish-deb.sh

echo "--- Git diff after build is complete:"
#git diff --exit-code -- .
