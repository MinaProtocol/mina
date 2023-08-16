#!/bin/bash
set -eo pipefail

# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3
#NOTE: Do not remove --lock flag otherwise racing deb uploads may overwrite the registry and some files will be lost. If a build fails with the following error, delete the lock file https://packages.o1test.net/dists/unstable/main/binary-/lockfile and rebuild
#>> Checking for existing lock file
#>> Repository is locked by another user:  at host dc7eaad3c537
#>> Attempting to obtain a lock
#/var/lib/gems/2.3.0/gems/deb-s3-0.10.0/lib/deb/s3/lock.rb:24:in `throw': uncaught throw #"Unable to obtain a lock after 60, giving up."
DEBS3='deb-s3 upload '\
'--s3-region=us-west-2 '\
'--bucket packages.o1test.net '\
'--lock '\
'--preserve-versions '\
'--cache-control=max-age=120 '

DEBS='_build/mina-*.deb'

#check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run"
    exit 0
fi

set +x
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source "${SCRIPTPATH}/export-git-env-vars.sh"
set -x

echo "Publishing debs: ${DEBS} to Release: ${MINA_DEB_RELEASE} and Codename: ${MINA_DEB_CODENAME}"
# Upload the deb files to s3.
# If this fails, attempt to remove the lockfile and retry.
${DEBS3} --component "${MINA_DEB_RELEASE}" --codename "${MINA_DEB_CODENAME}" "${DEBS}" \
|| (  scripts/clear-deb-s3-lockfile.sh \
   && ${DEBS3} --component "${MINA_DEB_RELEASE}" --codename "${MINA_DEB_CODENAME}" "${DEBS}")
set +x

# Verify upload is complete
case "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" in
  rampup|berkeley|release/2.0.0|develop)
    TESTNET_NAME="berkeley"
  ;;
  *)
    TESTNET_NAME="mainnet"
esac


echo "Installing mina daemon package: mina-${TESTNET_NAME}=${MINA_DEB_VERSION}"
sudo echo "deb [trusted=yes] http://packages.o1test.net $MINA_DEB_CODENAME $MINA_DEB_RELEASE" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get update

function verify_size_and_md5 {
    DEB_NAME="$1=$MINA_DEB_VERSION"
    SIZE=$(sudo apt-cache show $DEB_NAME | sed -n 's/^Size: //p')
    MD5=$(sudo apt-cache show $DEB_NAME | sed -n 's/^MD5sum: //p')
    FILENAME="_build/$1_${MINA_DEB_VERSION}.deb"
    FILENAME_SIZE=$(stat -c "%s" $FILENAME)
    FILENAME_MD5=$(md5sum ${FILENAME} | awk '{ print $1 }')

    echo "comparing sizes of $DEB_NAME between http://packages.o1test.net and local file.."
    if [[ "$SIZE" -ne "$FILENAME_SIZE" ]]; then
        echo "local deb file has $FILENAME_SIZE size while remote is $SIZE"
        exit -1
    fi
    echo "$DEB_NAME has identical size locally and on http://packages.o1test.net"

    echo "comparing md5 hashes of $DEB_NAME between http://packages.o1test.net and local file.."
    if [[ "$MD5" != "$FILENAME_MD5" ]]; then
        echo "local deb file has $FILENAME_MD5 md5sum while remote is $MD5"
        exit -1
    fi
    echo "$DEB_NAME has identical md5 locally and on http://packages.o1test.net"

}

# In order to prevent anyone to use freshly pushed packages prematurely we need to be sure those packages has correct
# md5 and sizes before finishing script
function verify_o1test_repo_is_synced {
    verify_size_and_md5 "mina-${TESTNET_NAME}"
    verify_size_and_md5 "mina-archive"
}

for i in {1..5}; do verify_o1test_repo_is_synced && break || sleep 60; done