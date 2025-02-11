#!/usr/bin/env bash
set -eox pipefail

CHANNEL=umt-mainnet
VERSION=3.0.0-f872d85
CODENAME=bullseye
BUCKET=packages.o1test.net

while [[ "$#" -gt 0 ]]; do case $1 in
  -c|--channel) CHANNEL="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -p|--package) PACKAGE="$2"; shift;;
  -m|--codename) CODENAME="$2"; shift;;
  -b|--bucket) BUCKET="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

if [ -z "${PACKAGE}" ]; then
  echo "No package defined. exiting.."; exit 1;
fi

case $PACKAGE in
  mina-archive) COMMAND="mina-archive --version && mina-archive --help" ;;
  mina-logproc) COMMAND="echo skipped execution for mina-logproc" ;;
  mina-*) COMMAND="mina --version && mina --help" ;;
  *) echo "Unknown package passed: $PACKAGE"; exit 1;;
esac

SCRIPT=' set -x \
    && export DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC \
    && echo installing mina \
    && apt-get update > /dev/null \
    && apt-get install -y lsb-release ca-certificates > /dev/null \
    && echo "deb [trusted=yes] https://'$BUCKET' '$CODENAME' '$CHANNEL'" > /etc/apt/sources.list.d/mina.list \
    && apt-get update > /dev/null \
    && apt list -a '$PACKAGE' \
    && apt-get install -y --allow-downgrades '$PACKAGE'='$VERSION' \
    && '$COMMAND' 
    '

case $CODENAME in
  bullseye) DOCKER_IMAGE="debian:bullseye" ;;
  focal) DOCKER_IMAGE="ubuntu:focal" ;;
  *) echo "Unknown codename passed: $CODENAME"; exit 1;;
esac

echo "Testing packages on all images" \
  && docker run --rm $DOCKER_IMAGE bash -c "$SCRIPT" \
  && echo 'OK: ALL WORKED FINE!' || (echo 'KO: ERROR!!!' && exit 1)
