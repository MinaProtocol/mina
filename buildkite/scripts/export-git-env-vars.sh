#!/bin/bash

# This script should be never run outside buildkite agent

source ./scripts/export-git-env-vars.sh

# Always prefer buildkite branch even if ./scripts/export-git-env-vars.sh 
# calculate GITBRANCH on its own
export GITBRANCH=$BUILDKITE_BRANCH 

export BUILD_NUM=${BUILDKITE_BUILD_NUMBER}
export BUILD_URL=${BUILDKITE_BUILD_URL}

source ./buildkite/scripts/handle-fork.sh