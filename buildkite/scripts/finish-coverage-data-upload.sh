curl -k https://coveralls.io/webhook?repo_token=$COVERALLS_TOKEN -d "payload[build_num]=$BUILDKITE_BUILD_NUMBER&payload[status]=done"

curl --location --request POST "https://coveralls.io/rerun_build?repo_token=$COVERALLS_TOKEN&build_num=$BUILDKITE_BUILD_NUMBER"