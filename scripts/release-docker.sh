#!/usr/bin/env bash

# Author's Note: Because the structure of this repo is inconsistent (Dockerfiles and build contexts placed willy-nilly)
# we have to trustlist and configure image builds individually because each one is going to be slightly different.
# This is needed as opposed to trusting the structure of the each project to be consistent for every deployable.

set -eo pipefail
set +x

DHALL_VERSION=1.41.1
DHALL_JSON_VERSION=1.7.10
DHALL_BASH_VERSION=1.0.40

tempdir=$(mktemp -d dhall-XXX)
mkdir -p "$tempdir/bin"

dhall-to-bash() {
  if type -P dhall-to-bash > /dev/null; then
    command dhall-to-bash "$@"
  else
    mkdir -p "$tempdir/bin"
    printf "> Downloading dhall-bash to %s <\n" "$tempdir" > /dev/stderr
    curl -sL https://github.com/dhall-lang/dhall-haskell/releases/download/$DHALL_VERSION/dhall-bash-$DHALL_BASH_VERSION-x86_64-linux.tar.bz2 \
    | tar --extract --file=- --bzip2 --directory="$tempdir" ./bin/dhall-to-bash
    "$tempdir/bin/dhall-to-bash" "$@"
    code="$?"
    return $code
  fi
}

# shellcheck disable=SC2120
dhall-to-yaml() {
  if type -P dhall-to-yaml > /dev/null; then
    command dhall-to-yaml "$@"
  else
    printf "> Downloading dhall-json to %s <\n" "$tempdir" > /dev/stderr
    curl -sL https://github.com/dhall-lang/dhall-haskell/releases/download/$DHALL_VERSION/dhall-json-$DHALL_JSON_VERSION-x86_64-linux.tar.bz2 \
    | tar --extract --file=- --bzip2 --directory="$tempdir" ./bin/dhall-to-yaml
    "$tempdir/bin/dhall-to-yaml" "$@"
    code="$?"
    return $code
  fi
}

cleanup() {
  rm -rf "$tempdir"
}

trap cleanup EXIT

CLEAR='\033[0m'
RED='\033[0;31m'
# Array of valid service names
VALID_SERVICES=('mina-archive' 'mina-daemon' 'mina-rosetta' 'mina-toolchain' 'mina-builder' 'mina-opam-deps' 'delegation-backend' 'delegation-backend-toolchain' 'mina-test-executive')

ROOT="$(cd -- "$(dirname "$( dirname -- "${BASH_SOURCE[0]}" )")" &> /dev/null && pwd )"

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-s service-to-release] [-v service-version] [-n network]"
  echo "  -s, --service             The Service being released to Dockerhub"
  echo "  -v, --version             The version to be used in the docker image tag"
  echo "  -n, --network             The network configuration to use (devnet or mainnet). Default=devnet"
  echo "  -b, --branch              The branch of the mina repository to use for staged docker builds. Default=compatible"
  echo "  -c, --commit              The commit of the mina repository to use for staged docker builds. Default=tip of master"
  echo "      --deb-codename        The debian codename (stretch or buster) to build the docker image from. Default=stretch"
  echo "      --deb-release         The debian package release channel to pull from (unstable,alpha,beta,stable). Default=unstable"
  echo "      --deb-version         The version string for the debian package to install"
  echo "      --opam-deps           The Opam Deps stage to re-use dependencies from"
  echo "      --builder             The Builder stage to re-use dependencies from"
  echo ""
  echo "Example: $0 --service faucet --version v0.1.0"
  echo "Valid Services: ${VALID_SERVICES[*]}"
  exit 1
}

FUNCTION=kanikoBuild
LOGS_BUCKET=",logsBucket = Some \"gs://mina-cloudbuild-logs\""

extraArgs=()

while [[ "$#" -gt 0 ]]; do case $1 in
  -s|--service) SERVICE="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -n|--network) NETWORK=", network = Some \"$2\""; shift;;
  -b|--branch) BRANCH=", branch = Some \"$2\""; shift;;
  -c|--commit) COMMIT=", commit = Some \"$2\""; shift;;
  --cache-from) CACHE=", cache = Some \"$2\""; shift;;
  --deb-codename) DEB_CODENAME=", debCodename = Some cb.DebCodename.$2"; shift;;
  --deb-release) DEB_RELEASE=", debRelease = Some \"$2\""; shift;;
  --deb-version) DEB_VERSION=", debVersion = Some \"$2\""; shift;;
  --logs-bucket) LOGS_BUCKET=", logsBucket = Some \"$2\""; shift;;
  --opam-deps) OPAM_DEPS_STAGE=", opamDeps = Some \"$2\""; shift;;
  --builder) BUILDER_STAGE=", builder = Some \"$2\""; shift;;
  --local) FUNCTION=dockerBuild ;;
  --extra-arg) extraArgs+=("\"$2\""); shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

if [ -n "${extraArgs[*]}" ]; then
  EXTRA=", extraArgs = [$(IFS=, ; echo "${extraArgs[*]}")]"
else
  EXTRA=""
fi

# Determine the proper image for ubuntu or debian
case "${DEB_CODENAME##*=}" in
  bionic|focal|impish|jammy)
    IMAGE="ubuntu:${DEB_CODENAME##*=}"
  ;;
  stretch|buster|bullseye|bookworm|sid)
    IMAGE="debian:${DEB_CODENAME##*=}-slim"
  ;;
esac
IMAGE="--build-arg image=${IMAGE}"

# Debug prints for visability
# Substring removal to cut the --build-arg arguments on the = so that the output is exactly the input flags https://wiki.bash-hackers.org/syntax/pe#substring_removal
echo "--service ${SERVICE} --version ${VERSION} --branch ${BRANCH##*=} --deb-version ${DEB_VERSION##*=} --deb-release ${DEB_RELEASE##*=} --deb-codename ${DEB_CODENAME##*=}"
echo ${EXTRA}
echo "docker image: ${IMAGE}"

# Verify Required Parameters are Present
if [[ -z "$SERVICE" ]]; then usage "Service is not set!"; fi;
if [[ -z "$VERSION" ]]; then usage "Version is not set!"; fi;

if [[ -n "${BUILDKITE_PULL_REQUEST_REPO}" ]]; then
  REPO=", repo = Some \"${BUILDKITE_PULL_REQUEST_REPO}\""
fi

# Remove some unused build-args depending on the service
if [ "${SERVICE}" != "mina-daemon" ]; then
  NETWORK=", network = None Text"
fi

case "${SERVICE}" in
  # pulled from builder image, but needs to pull a branch as well
  mina-test-executive)
    COMMIT=", commit = None Text"
    ;;
  # pulled from debian builder image, no need for commit or branch
  mina-daemon|mina-archive|mina-generate-keypair)
    COMMIT=", commit = None Text"
    BRANCH=", branch = None Text"
    ;;
  # pulled and built exclusively based on branch, no need for commit or deb repo
  mina-toolchain)
    COMMIT=", commit = None Text"
    DEB_VERSION=", debVersion = None Text"
    DEB_RELEASE=", debRelease = None Text"
    ;;
  # pulled and built based on commit and branch, no need for deb repo
  mina-rosetta)
    DEB_VERSION=", debVersion = None Text"
    DEB_RELEASE=", debRelease = None Text"
    ;;
esac

pushd "$ROOT"

dhall="
  let cb = ./dockerfiles/cloudbuild.dhall
  in cb.$FUNCTION cb.$SERVICE cb.ServiceDescription::
       { version = \"$VERSION\"
       $REPO
       $NETWORK
       $BRANCH
       $COMMIT
       $CACHE
       $DEB_CODENAME
       $DEB_RELEASE
       $DEB_VERSION
       $LOGS_BUCKET
       $OPAM_DEPS_STAGE
       $BUILDER_STAGE
       $EXTRA
       }
"
DOCKER_REGISTRY="gcr.io/o1labs-192920"
TAG="${DOCKER_REGISTRY}/${SERVICE}:${VERSION}"
# friendly, predictable tag
GITHASH=$(git rev-parse --short=7 HEAD)
HASHTAG="${DOCKER_REGISTRY}/${SERVICE}:${GITHASH}-${DEB_CODENAME##*=}-${NETWORK##*=}"

if [[ $FUNCTION == cloudBuild ]]; then
    dhall-to-yaml <<< "$dhall" | tee /dev/stderr > cloudbuild.yaml
    gcloud builds submit
elif [[ $FUNCTION == dockerBuild ]]; then
    eval eval "$(dhall-to-bash <<< "$dhall")"
elif [[ $FUNCTION == kanikoBuild ]]; then
    dhall-to-yaml <<< "$dhall" | tee /dev/stderr > cloudbuild.yaml
    gcloud builds submit --config=./cloudbuild.yaml
else
    echo "Unknown function: $FUNCTION" > /dev/stderr
    exit 1
fi

popd
if [[ -z "$NOUPLOAD" ]] || [[ "$NOUPLOAD" -eq 0 ]]; then
  
  echo "Release Env Var: ${DEB_RELEASE}"
  echo "Release: ${DEB_RELEASE##*=}"

  if [[ "${DEB_RELEASE##*=}" = "unstable" ]]; then
    echo "Release is unstable: not pushing to docker hub"
  else
    echo "Release is public (alpha, beta, berkeley, or stable): pushing image to docker hub"
    # tag and push to dockerhub
    docker tag "${TAG}" "minaprotocol/${SERVICE}:${VERSION}"
    docker push "minaprotocol/${SERVICE}:${VERSION}"
  fi
fi
