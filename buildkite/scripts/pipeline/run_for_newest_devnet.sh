#!/bin/bash

if [[ -z "$BUILDKITE_AGENT_WRITE_TOKEN" ]]; then
  echo "BUILDKITE_AGENT_WRITE_TOKEN is not set"
  exit 1
fi

FORKING_BRANCH=$BUILDKITE_BRANCH
PREFIX="https://storage.googleapis.com/o1labs-gitops-infrastructure/pre-mesa/pre-mesa-1-hardfork"

export BUILDKITE_API_TOKEN=$BUILDKITE_AGENT_WRITE_TOKEN

cd ./buildkite/scripts/pipeline || exit

make build

./bin/hardfork-runner \
    -latest-config-from-prefix ${PREFIX} \
    -monitor \
    -branch ${FORKING_BRANCH}
