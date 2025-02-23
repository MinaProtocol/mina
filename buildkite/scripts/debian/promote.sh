#!/bin/bash

CLEAR='\033[0m'
RED='\033[0;31m'

while [[ "$#" -gt 0 ]]; do case $1 in
  -p|--package) PACKAGE="$2"; shift;;
  --version) VERSION="$2"; shift;;
  --new-version) NEW_VERSION="$2"; shift;;
  -a|--architecture) ARCH="$2"; shift;;
  -c|--codename) CODENAME="$2"; shift;;
  -s|--from-component) FROM_COMPONENT="$2"; shift;;
  -t|--to-component) TO_COMPONENT="$2"; shift;;
  --new-name) NEW_NAME="$2"; shift;;
  --new-repo) NEW_REPO="$2"; shift;;
  -r|--repo) REPO="$2"; shift;;
  --repo-key) REPO_KEY="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-p package] [--version version] [--new-version version] [-a architecture] [-s from-component] [-t to-component] [-c codename ]"
  echo "  -p, --package          The Package name (mina-logproc, mina-archive etc.)"
  echo "  --version              The Debian version"
  echo "  --new-version          The Debian version"
  echo "  --new-name             The New Package name"
  echo "  -a, --architecture     The Debian package architecture (amd64 etc.)"
  echo "  -s, --from-component   The source channel in which package currently resides"
  echo "  -t, --to-component     The target channel for package (unstable, alpha, beta etc.)"
  echo "  -c, --codename         The Debian codename (bullseye, focal etc.)"
  echo "  -r, --repo             The Debian source repo"
  echo "  --new-repo             The Debian target repo. By default equal to repo"
  echo "  --repo-key         The Debian target repo key"
  echo ""
  echo "Example: $0 --package mina-archive --version 2.0.0-rc1-48efea4 --architecture amd64 --codename bullseye --from-component unstable --to-component nightly"
  exit 1
}

if [[ -z "$PACKAGE" ]]; then usage "Package is not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;
if [[ -z "$ARCH" ]]; then usage "Architecture is not set!"; fi;
if [[ -z "$CODENAME" ]]; then usage "Codename is not set!"; fi;
if [[ -z "$NEW_NAME" ]]; then NEW_NAME=$PACKAGE; fi;
if [[ -z "$FROM_COMPONENT" ]]; then usage "Source component is not set!"; fi;
if [[ -z "$TO_COMPONENT" ]]; then usage "Target component is not set!"; fi;
if [[ -z "$REPO" ]]; then usage "Repository is not set!"; fi;
if [[ -z "$NEW_REPO" ]]; then NEW_REPO=$REPO; fi;
if [ -z "${REPO_KEY:-}" ]; then
  SIGN_ARG=""
else
  sudo chown -R opam ~/.gnupg/
  gpg --batch --yes --import /var/secrets/debian/key.gpg
  SIGN_ARG="--sign $REPO_KEY"
fi

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, promote commands won't run"
    exit 0
fi

source buildkite/scripts/export-git-env-vars.sh

echo "Promoting debs: ${PACKAGE}_${VERSION} to Release: ${TO_COMPONENT} and Codename: ${CODENAME}"
# Promote the deb .
# If this fails, attempt to remove the lockfile and retry.

source scripts/debian/reversion.sh \
    --deb $PACKAGE  \
    --codename $CODENAME \
    --new-release $TO_COMPONENT \
    --release $FROM_COMPONENT \
    --version $VERSION \
    --new-version $NEW_VERSION \
    --suite $FROM_COMPONENT \
    --new-suite $TO_COMPONENT \
    --new-name $NEW_NAME \
    --repo $REPO \
    --new-repo $NEW_REPO \
    $SIGN_ARG