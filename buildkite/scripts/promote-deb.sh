#!/bin/bash
set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'

while [[ "$#" -gt 0 ]]; do case $1 in
  -p|--package) PACKAGE="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -a|--architecture) ARCH="$2"; shift;;
  -c|--codename) CODENAME="$2"; shift;;
  -s|--from-component) FROM_COMPONENT="$2"; shift;;
  -t|--to-component) TO_COMPONENT="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-p package] [-v version] [-a architecture] [-s from-component] [-t to-component] [-c codename ]"
  echo "  -p, --package          The Package name (mina-logproc, mina-archive etc.)"
  echo "  -v, --version          The Debian version"
  echo "  -a, --architecture     The Debian package architecture (amd64 etc.)"
  echo "  -s, --from-component   The source channel in which package currently resides"
  echo "  -t, --to-component     The target channel for package (unstable, alpha, beta etc.)"
  echo "  -c, --codename         The Debian codename (bullseye, focal etc.)"
  echo ""
  echo "Example: $0 --package mina-archive --version 2.0.0berkeley-rc1-berkeley-48efea4 --architecture amd64 --codename bullseye --from-component unstable --to-component nightly"
  exit 1
}

if [[ -z "$PACKAGE" ]]; then usage "Package is not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;
if [[ -z "$ARCH" ]]; then usage "Architecture is not set!"; fi;
if [[ -z "$CODENAME" ]]; then usage "Codename is not set!"; fi;
if [[ -z "$FROM_COMPONENT" ]]; then usage "Source component is not set!"; fi;
if [[ -z "$TO_COMPONENT" ]]; then usage "Target component is not set!"; fi;

# utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3
#NOTE: Do not remove --lock flag otherwise racing deb uploads may overwrite the registry and some files will be lost. If a build fails with the following error, delete the lock file https://packages.o1test.net/dists/unstable/main/binary-/lockfile and rebuild
#>> Checking for existing lock file
#>> Repository is locked by another user:  at host dc7eaad3c537
#>> Attempting to obtain a lock
#/var/lib/gems/2.3.0/gems/deb-s3-0.10.0/lib/deb/s3/lock.rb:24:in `throw': uncaught throw #"Unable to obtain a lock after 60, giving up."

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, promote commands won't run"
    exit 0
fi

echo "Promoting debs: ${PACKAGE}_${VERSION} to Release: ${TO_COMPONENT} and Codename: ${CODENAME}"
# Promote the deb .
# If this fails, attempt to remove the lockfile and retry.
deb-s3 copy --s3-region=us-west-2 --bucket packages.o1test.net --preserve-versions --cache-control=max-age=120  $PACKAGE $CODENAME $TO_COMPONENT --versions $VERSION --arch $ARCH --component ${FROM_COMPONENT} --codename ${CODENAME}