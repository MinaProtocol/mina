#!/bin/bash
set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'

ARCH=amd64

while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--names) DEB_NAMES="$2"; shift;;
  -r|--release) DEB_RELEASE="$2"; shift;;
  -v|--version) DEB_VERSION="$2"; shift;;
  -c|--codename) DEB_CODENAME="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-n name] [-r release] [-v version] [-c codename]"
  echo "  -n, --name          The Debian archive name"
  echo "  --names             The Debians archive names"
  echo "  -r, --release       The Debian release"
  echo "  -v, --version       The Debian version"
  echo "  -c, --codename      The Debian codename"
  echo ""
  echo "Example: $0 --name mina-archive_2.0.0berkeley-rc1-berkeley-48efea4 --release unstable --version 2.0.0berkeley-rc1-berkeley-48efea4 --codename bullseye "
  exit 1
}

if [[ -z "$DEB_NAMES" ]]; then usage "Debian(s) to upload are not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;
if [[ -z "$CODENAME" ]]; then usage "Codename is not set!"; fi;
if [[ -z "$RELEASE" ]]; then usage "Release is not set!"; fi;


BUCKET_ARG='--bucket packages.o1test.net'
S3_REGION_ARG='--s3-region=us-west-2'
# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3
#NOTE: Do not remove --lock flag otherwise racing deb uploads may overwrite the registry and some files will be lost. If a build fails with the following error, delete the lock file https://packages.o1test.net/dists/unstable/main/binary-/lockfile and rebuild
#>> Checking for existing lock file
#>> Repository is locked by another user:  at host dc7eaad3c537
#>> Attempting to obtain a lock
#/var/lib/gems/2.3.0/gems/deb-s3-0.10.0/lib/deb/s3/lock.rb:24:in `throw': uncaught throw #"Unable to obtain a lock after 60, giving up."
DEBS3_UPLOAD="deb-s3 upload $BUCKET_ARG $S3_REGION_ARG \
  --lock \
  --preserve-versions \
  --cache-control=max-age=120"

echo "Publishing debs: ${DEB_NAMES} to Release: ${DEB_RELEASE} and Codename: ${DEB_CODENAME}"
# Upload the deb files to s3.
# If this fails, attempt to remove the lockfile and retry.
${DEBS3_UPLOAD} --component "${DEB_RELEASE}" --codename "${DEB_CODENAME}" "${DEB_NAMES}" \
|| (  scripts/clear-deb-s3-lockfile.sh \
   && ${DEBS3_UPLOAD} --component "${DEB_RELEASE}" --codename "${DEB_CODENAME}" "${DEB_NAMES}")
set +x

# Verify integrity of debs on remote repo


function verify_o1test_repo_has_package {
  sudo apt-get update
  ${DEBS3_SHOW} ${DEB} ${DEB_VERSION} $ARCH -c $DEB_CODENAME -m $DEB_RELEASE
  return $?
}

for deb in $DEB_NAMES
do
  echo "Adding packages.o1test.net $DEB_CODENAME $DEB_RELEASE"
  sudo echo "deb [trusted=yes] http://packages.o1test.net $DEB_CODENAME $DEB_RELEASE" | sudo tee /etc/apt/sources.list.d/mina.list

  DEBS3_SHOW="deb-s3 show $BUCKET_ARG $S3_REGION_ARG"

  deb_split=(${deb//_/ })
  deb="${deb_split[0]}"
  deb=$(basename $deb)
  
  for i in {1..10}; do verify_o1test_repo_has_package && break || sleep 60; done

done


