#!/bin/bash

set -eo pipefail

([ -z ${DUNE_PROFILE+x} ] || [ -z ${MINA_DEB_CODENAME+x} ]) && echo "required env vars were not provided" && exit 1

source ~/.profile

./buildkite/scripts/build-artifact.sh

echo "--- Bundle all packages for Debian ${MINA_DEB_CODENAME}"
echo " Includes mina daemon, archive-node, rosetta, generate keypair for berkeley"
[[ ${MINA_BUILD_MAINNET} ]] && echo " MINA_BUILD_MAINNET is true so this includes the mainnet and devnet packages for mina-daemon as well"


echo "--- Prepare debian packages"
./scripts/rebuild-deb.sh $@

ls -al

echo "--- Copy debians to s3"
for entry in *.deb; do
  source ./buildkite/scripts/cache-artifact.sh $entry ${MINA_DEB_CODENAME}/debs
done 

echo "--- Git diff after build is complete:"
git diff --exit-code -- .
