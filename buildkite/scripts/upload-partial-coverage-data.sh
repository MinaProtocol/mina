#!/bin/bash

TEST_NAME=$1

echo "--- Checking for coverage artifacts"

if test -n "$(find -name '*.coverage' -print -quit)"
then
    echo "--- Creating coverage report"

    opam exec -- bisect-ppx-report coveralls --git --service-name buildkite  --service-job-id $BUILDKITE_BUILD_NUMBER \
    --coverage-path . --parallel --repo-token=$COVERALLS_TOKEN coverage.json

    echo "--- Updating coverage report context with branch an unique flag name"

    jq '.git.branch = "'$BUILDKITE_BRANCH'"' coverage.json  > tmp.json && mv tmp.json coverage.json
    jq '.flag_name = "'$TEST_NAME'"' coverage.json  > tmp.json && mv tmp.json coverage.json

    echo "--- Sending coverage report to coveralls"

    curl -X POST https://coveralls.io/api/v1/jobs -F 'json_file=@coverage.json'
else
     echo "--- Skipping coverage step as no *.coverage files found"
fi

