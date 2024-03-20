#!/bin/bash

set -eo pipefail

([ -z ${DUNE_PROFILE+x} ] || [ -z ${MINA_DEB_CODENAME+x} ]) && echo "required env vars were not provided" && exit 1

if [[ $1 = "archive_migration" ]] ; then
    curl -O https://gist.githubusercontent.com/emberian/d1435ac373cd014a2c3054946bb6cd39/raw/caqti-upgrade.patch
    git apply caqti-upgrade.patch
fi

source ~/.profile

./buildkite/scripts/build-artifact.sh

echo "--- Bundle all packages for Debian ${MINA_DEB_CODENAME}"
echo " Includes mina daemon, archive-node, rosetta, generate keypair for berkeley"
[[ ${MINA_BUILD_MAINNET} ]] && echo " MINA_BUILD_MAINNET is true so this includes the mainnet and devnet packages for mina-daemon as well"


echo "--- Prepare debian packages"
./scripts/rebuild-deb.sh $@

echo "--- Upload debs to amazon s3 repo"
./buildkite/scripts/publish-deb.sh

if [[ $1 = "archive_migration" ]] ; then 
    git restore .
fi

echo "--- Git diff after build is complete:"
git diff --exit-code -- .
