#!/bin/bash

TEST_NAME=$1
PROFILE=$2

echo "--- Checking for coverage artifacts"

if test -n "$(find -name '*.coverage' -print -quit)"
then
    echo "--- Creating coverage report"

    if [[ "$PROFILE" == "dev" ]]; then
        echo "--- Dev environment detected... using opam to run bisect-ppx-report"

        opam exec -- bisect-ppx-report coveralls --git --service-name buildkite  --service-job-id $BUILDKITE_BUILD_NUMBER \
            --coverage-path . --parallel --repo-token=$COVERALLS_TOKEN coverage.json
    else 
        echo "--- Release environment detected... downloading bisect-ppx-report"
        curl -0 https://unpkg.com/bisect_ppx@2.7.1/bin/linux/bisect-ppx-report  > bisect-ppx-report
        chmod +x ./bisect-ppx-report
        ./bisect-ppx-report coveralls --git --service-name buildkite  --service-job-id $BUILDKITE_BUILD_NUMBER \
            --coverage-path . --parallel --repo-token=$COVERALLS_TOKEN coverage.json --ignore-missing-files
    fi

    echo "--- Updating coverage report context with branch an unique flag name"

    jq '.git.branch = "'$BUILDKITE_BRANCH'"' coverage.json  > tmp.json && mv tmp.json coverage.json
    jq '.flag_name = "'$TEST_NAME'"' coverage.json  > tmp.json && mv tmp.json coverage.json

    echo "--- Sending coverage report to coveralls"

    curl -X POST https://coveralls.io/api/v1/jobs -F 'json_file=@coverage.json'
else
     echo "--- Skipping coverage step as no *.coverage files found"
fi

