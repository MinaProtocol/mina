#!/usr/bin/env bash
set -eo pipefail

REPO=packages.o1test.net
SIGNED=0

function usage() {
  echo "Usage: $0 -c <channel> -r <repository> -v <version> -p <package> -m <codename> [-s]"
  echo "  -c, --channel    Channel to use (stable, beta, dev)"
  echo "  -r, --repo       Repository to use (default: packages.o1test.net)"
  echo "  -v, --version    Version to install"
  echo "  -p, --package    Package to install"
  echo "  -m, --codename   Codename of the distribution (focal, bullseye)"
  echo "  -s, --signed     Add the repository signing key"
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -c|--channel) CHANNEL="$2"; shift;;
  -r|--repo) REPO="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -p|--package) PACKAGE="$2"; shift;;
  -m|--codename) CODENAME="$2"; shift;;
  -s|--signed) SIGNED=1; ;;
  -h|--help) usage; exit 0;;
  *) echo "❌  Unknown parameter passed: $1"; usage;  exit 1;;
esac; shift; done

if [ -z $PACKAGE ]; then
  echo "❌  No package defined. "
  echo "❌  Did you forget to pass --package?"
  echo "" 
  usage; exit 1;
fi

if [ -z $VERSION ]; then
  echo "❌  No version defined."; 
  echo "❌  Did you forget to pass --version?";
  echo ""
  usage; exit 1;
fi

if [ -z $CODENAME ]; then
  echo "❌  No codename defined.";
  echo "❌  Did you forget to pass --codename?";
  echo ""
  usage; exit 1;
fi

if [ -z $CHANNEL ]; then
  echo "❌  No channel defined.";
  echo "❌  Did you forget to pass --channel?";
  echo ""
  usage; exit 1;
fi

if [ -z $REPO ]; then
  echo "❌  No repository defined."; 
  echo "❌  Did you forget to pass --repo?";
  echo ""
  usage; exit 1;
fi

case $PACKAGE in
  mina-archive) COMMAND="mina-archive --version && mina-archive --help" ;;
  mina-logproc) COMMAND="echo skipped execution for mina-logproc" ;;
  mina-rosetta*) COMMAND="echo skipped execution for mina-rosetta" ;;
  mina-*) COMMAND="mina --version && mina --help" ;;
  *) echo "❌  Unknown package passed: $PACKAGE"; exit 1;;
esac

if [[ "$SIGNED" ]]; then
  SIGNED=" (wget -q https://'$REPO'/repo-signing-key.asc -O- | apt-key add) && apt-get update > /dev/null && "
else 
  SIGNED=""
fi


SCRIPT=' set -x \
    && export DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC \
    && echo installing '$PACKAGE' \
    && apt-get update > /dev/null \
    && apt-get install -y lsb-release ca-certificates wget gnupg > /dev/null \
    && '$SIGNED' echo "deb [trusted=yes] https://'$REPO' '$CODENAME' '$CHANNEL'" > /etc/apt/sources.list.d/mina.list \
    && apt-get update > /dev/null \
    && apt list -a '$PACKAGE' \
    && apt-get install -y --allow-downgrades '$PACKAGE'='$VERSION' \
    && '$COMMAND' 
    '

case $CODENAME in
  bullseye) DOCKER_IMAGE="debian:bullseye" ;;
  focal) DOCKER_IMAGE="ubuntu:focal" ;;
  *) echo "❌  Unknown codename passed: $CODENAME"; exit 1;;
esac

echo "📋  Testing $PACKAGE $DOCKER_IMAGE" \
  && docker run --rm $DOCKER_IMAGE bash -c "$SCRIPT" \
  && echo '✅  OK: ALL WORKED FINE!' || (echo '❌  KO: ERROR!!!' && exit 1)
