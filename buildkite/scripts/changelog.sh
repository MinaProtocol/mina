#!/bin/bash

TRIGGER=$1
REQUIRED_CHANGE=$2

set -eou pipefail

source "./buildkite/scripts/refresh_code.sh"

# make sure we cleaned gits
git clean -fd


if [[ $BUILDKITE_PIPELINE_SLUG == "mina-end-to-end-nightlies" ]]; then
    echo "Skipping run on nightly"
    exit 0
fi

if [[ ! "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" ]]; then 
    echo "BUILDKITE_PULL_REQUEST_BASE_BRANCH env variable is not defined"
    echo "Did you run this job without !ci-build-me ?"
    exit 1
fi

COMMIT=$(git log -1 --pretty=format:%H)
BASE_COMMIT=$(git log "${REMOTE}/${BUILDKITE_PULL_REQUEST_BASE_BRANCH}" -1 --pretty=format:%H)
echo "Diffing current commit: ${COMMIT} against branch: ${BUILDKITE_PULL_REQUEST_BASE_BRANCH} (${BASE_COMMIT})" >&2 
git diff "${REMOTE}/${BUILDKITE_PULL_REQUEST_BASE_BRANCH}" --name-only > _computed_diff.txt

if (cat _computed_diff.txt | grep -E -q "$TRIGGER"); then
    if ! (cat _computed_diff.txt | grep -E -q "$REQUIRED_CHANGE"); then
        echo "Missing changelog entry detected !!"
        echo ""
        echo "This job detected that you modified important part of code and did not update changelog file."
        echo "Please ensure that you added this change to our changelog file: "
        echo "'${reqFile}'"
        echo " where syntax is like below: "
        echo " changes/{PR number}-{description}.md"
        echo " from example: changes/13523-new-fancy-daemon-feature.md"
        echo "It will help us to produce Release Notes for upcoming release"
        exit 1
    else
        echo "Changelog updated!"
    fi
fi