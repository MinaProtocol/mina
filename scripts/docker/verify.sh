#!/usr/bin/env bash
set +x

REPO=gcr.io/o1labs-192920
VERSION=3.0.0-f872d85

while [[ "$#" -gt 0 ]]; do case $1 in
  -p|--package) PACKAGE="$2"; shift;;
  -c|--codename) CODENAME="$2"; shift;;
  -s|--suffix) SUFFIX="$2"; shift;;
  -r|--repo) REPO="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

if [ -z $PACKAGE ]; then
  echo "❌  No package defined. Did you forget to pass --package?"
  exit 1;
fi
if [ -z $CODENAME ]; then
  echo "❌  No codename defined. Did you forget to pass --codename?"
  exit 1;
fi
if [ -z $REPO ]; then
  echo "❌  No repository defined. Did you forget to pass --repo?"
  exit 1;
fi
if [ -z $VERSION ]; then
  echo "❌  No version defined. Did you forget to pass --version?"
  exit 1;
fi

DOCKER_IMAGE="$REPO/$PACKAGE:$VERSION-${CODENAME}${SUFFIX}"

if ! docker pull ${DOCKER_IMAGE} ; then
  echo "❌ Docker verification for $CODENAME $PACKAGE failed"
  exit 1
fi

case $PACKAGE in
  mina-archive) COMMAND="mina-archive --version && mina-archive --help" ;;
  mina-rosetta*) COMMAND="echo skipped execution for mina-rosetta" ;;
  mina-*) COMMAND="mina --version && mina --help" ;;
  *) echo "❌  Unknown package passed: $PACKAGE"; exit 1;;
esac


echo "✅ Docker verification for $CODENAME $PACKAGE passed"

echo "Running sanity checks for $PACKAGE" 

if docker run --entrypoint bash --rm $DOCKER_IMAGE bash -c "$COMMAND"; then
  echo "✅ Sanity checks passed for $PACKAGE"
else
  echo "❌ Sanity checks failed for $PACKAGE"
  exit 1
fi


