#!/bin/bash

set -euo pipefail

eval $(opam env)

git_tag=$(git describe --abbrev=0)
git_branch=$(echo $BUILDKITE_BRANCH | sed 's!/!-!; s!_!-!g')
# git_branch=$(git rev-parse --symbolic-full-name --abbrev-ref  HEAD  | sed 's!/!-!; s!_!-!g')
git_hash=$(git rev-parse --short=7 HEAD)

coda_daemon_image="codaprotocol/coda-daemon:${git_tag}-${git_branch}-${git_hash}"
export TF_LOG=DEBUG

echo "--- Building test-executive"

dune build --profile=testnet_postake_medium_curves src/app/test_executive/test_executive.exe

echo "--- Clone coda-automation repo (this would be changed in future. Nathan is suggesting linking coda-automation in coda repo)"

git clone https://github.com/CodaProtocol/coda-automation.git

echo "--- Set the credential for gcloud"

echo $BUILDKITE_GS_APPLICATION_CREDENTIALS_JSON > /tmp/credential.json

export GOOGLE_APPLICATION_CREDENTIALS="/tmp/credential.json"

echo "--- Set default region for AWS"

export AWS_DEFAULT_REGION=$AWS_REGION

echo "--- Run test executive"

./_build/default/src/app/test_executive/test_executive.exe --coda-image "$coda_daemon_image" block-production
