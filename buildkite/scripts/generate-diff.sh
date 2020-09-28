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
  git diff $COMMIT --name-only
else
  if [ -n "${INCREMENTAL_BUILD+x}" ]; then
    # based DIFF on last successful `develop` RUN as anchor
    ci_recent_pass_commit=$(
      curl https://graphql.buildkite.com/v1  -H "Authorization: Bearer $TOKEN"
        -d'{"query": "query { pipeline(slug: \"o-1-labs-2/coda\") { builds(first: 1 branch: \"develop\") { edges { node { commit } } } } }"}' | jq '.data.pipeline.builds.edges[0].node.commit'
    )
    git diff HEAD $ci_recent_pass_commit
  else
    git ls-files
  fi
fi

