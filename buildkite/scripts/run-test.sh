#!/bin/bash

set -euo pipefail

# Waiting for the coda-daemon image to be built by CircleCI (this is redundent once build-artifacts works in buildkite)

git_tag=$(git describe --abbrev=0)
git_branch=$(git rev-parse --symbolic-full-name --abbrev-ref  HEAD  | sed 's!/!-!; s!_!-!g')
git_hash=$(git rev-parse --short=7 HEAD)

coda_daemon_image="codaprotocol/coda-daemon:${git_tag}-${git_branch}-${git_hash}"

echo "Waiting for coda-daemon image to appear in docker registry"
for i in $(seq 60); do
    docker pull "$coda_daemon_image" && break
    [ "$i" != 30 ] || (echo "coda-daemon image never appeared in docker registry" && exit 1)
    sleep 60
done

# Building test-executive

dune build --profile=testnet_postake_medium_curves src/app/test_executive/test_executive.exe

# Clone coda-automation repo (this would be changed in future. Nathan is suggesting linking coda-automation in coda repo)

git clone git@github.com:CodaProtocol/coda-automation.git

# Set the credential for gcloud

echo $BUILDKITE_GS_APPLICATION_CREDENTIALS_JSON > credential.json

export GOOGLE_APPLICATION_CREDENTIALS="credential.json"

# Run test executive

./_build/default/src/app/test_executive/test_executive.exe --coda-image "$coda_daemon_image" block-production

