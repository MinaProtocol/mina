#!/bin/bash

# Base against origin/develop by default, but use pull-request base otherwise
BASE=${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-origin/develop}

# Finds the greatest common commit that is shared between these two branches
# Or nothing if there isn't one
COMMIT=$(diff -u <(git rev-list --first-parent HEAD) \
        <(git rev-list --first-parent $BASE) | \
        sed -ne 's/^ //p' | head -1)

if [[ $COMMIT != "" ]]; then
  # Get the files that have changed since that shared commit
  echo "--- Generating diff based on shared commit: ${COMMIT}"
  git diff $COMMIT --name-only
else
  if [ -n "${BUILDKITE_INCREMENTAL+x}" ]; then
    # base DIFF on last successful Buildkite `develop` RUN
    ci_recent_pass_commit=$(
      curl https://graphql.buildkite.com/v1 -H "Authorization: Bearer ${BUILDKITE_API_TOKEN:-$TOKEN}" \
        -d'{"query": "query { pipeline(slug: \"o-1-labs-2/coda\") { builds(first: 1 branch: \"develop\" state: PASSED) { edges { node { commit } } } } }"}' \
      | jq '.data.pipeline.builds.edges[0].node.commit' | tr -d '"'
    )

    echo "--- Generating incremental diff against: ${ci_recent_pass_commit}"
    git diff "${ci_recent_pass_commit}" --name-only
  else
    # TODO: Dump commits as artifacts when build succeeds so we can diff against
    # that on develop instead of always running all the tests
    git ls-files
  fi
fi

