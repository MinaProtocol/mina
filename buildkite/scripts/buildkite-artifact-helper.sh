#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 '<artifact-path>'"
    exit 1
fi

# Move to build checkout root to allow for artifact paths to be expressed relative to root
cd "${BUILDKITE_BUILD_CHECKOUT_PATH:-"../.."}
BUILDKITE_ARTIFACT_UPLOAD_DESTINATION="gs://buildkite_k8s/coda/shared/${BUILDKITE_JOB_ID}" buildkite-agent artifact upload "${1}"
