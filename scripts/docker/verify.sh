#!/usr/bin/env bash
set +x

set -eo pipefail

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


case $PACKAGE in
  mina-archive) COMMAND="mina-archive --version && mina-archive --help" ;;
  mina-logproc) COMMAND="echo skipped execution for mina-logproc" ;;
  mina-rosetta*) COMMAND="mina --version && mina --help && mina-archive --version && mina-archive --help && mina-rosetta --version && mina-rosetta --help" ;;
  mina-*) COMMAND="mina --version && mina --help" ;;
  *) echo "❌  Unknown package passed: $PACKAGE"; exit 1;;
esac

DOCKER_IMAGE="$REPO/$PACKAGE:$VERSION-${CODENAME}${SUFFIX}"

if ! docker pull $DOCKER_IMAGE ; then
  echo "❌ Docker verification for $CODENAME $PACKAGE failed"
  echo "❌ Please check if the image $DOCKER_IMAGE exists."
  exit 1
fi

echo "📋  Testing $PACKAGE $DOCKER_IMAGE" \
  && docker run --rm $DOCKER_IMAGE bash -c "$COMMAND" \
  && echo '✅  OK: ALL WORKED FINE!' || (echo '❌  KO: ERROR!!!' && exit 1)