#!/bin/bash

set -xeo pipefail

export MINA_REPO="https://github.com/MinaProtocol/mina.git"

if [ -z "${BUILDKITE_PULL_REQUEST_REPO}" ]; then
    echo "Unable to detect fork without BUILDKITE_PULL_REQUEST_REPO"
    echo "Looks like CI was ran without !ci-build-me skipping..."
    export FORK=0
    exit 0
fi

if [[ "${BUILDKITE_PULL_REQUEST_REPO}" ==  "${MINA_REPO}" ]]; then
    echo "This is not a Forked repo, skipping..."
    export FORK=0
else
    export FORK=1
fi