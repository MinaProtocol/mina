#!/bin/bash

source ./buildkite/scripts/handle-fork.sh
git fetch ${REMOTE} --recurse-submodules
git fetch ${REMOTE} --tags
git fetch ${REMOTE} --prune-tags