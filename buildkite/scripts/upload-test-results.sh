#!/bin/bash
set -o pipefail -x

TEST_NAME="$1"

if [[ "${TEST_NAME:0:15}" == "block-prod-prio" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

./test_reporter.exe test-result generate --log-file "$TEST_NAME.test.log" --format junit --output-file test_result.xml

curl -X POST https://analytics-api.buildkite.com/v1/uploads -sv \
  -H "Authorization: Token token=\"$BUILDKITE_TEST_ANALYTICS_TOKEN\"" \
  -F "data=@test_result.xml" \
  -F "format=junit" \
  -F "run_env[CI]=buildkite" \
  -F "run_env[key]=$BUILDKITE_BUILD_ID" \
  -F "run_env[number]=$BUILDKITE_BUILD_NUMBER" \
  -F "run_env[branch]=$BUILDKITE_BRANCH" \
  -F "run_env[commit_sha]=$BUILDKITE_COMMIT" \
  -F "run_env[url]=$BUILDKITE_BUILD_URL" \
  -F "run_env[message]=$BUILDKITE_MESSAGE"