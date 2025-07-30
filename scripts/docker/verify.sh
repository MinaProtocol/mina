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

if ! docker pull $REPO/$PACKAGE:$VERSION-${CODENAME}${SUFFIX} ; then
  echo "❌ Docker verification for $CODENAME $PACKAGE failed"
  exit 1
else
  echo "✅ Docker verification for $CODENAME $PACKAGE passed"
fi
