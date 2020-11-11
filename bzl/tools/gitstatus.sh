#!/bin/sh

echo "STABLE_GIT_COMMIT_ID $(git rev-parse --verify HEAD)"
echo "STABLE_GIT_BRANCH $(git rev-parse --verify --abbrev-ref HEAD || echo \"<none found>\")"
echo "STABLE_GIT_COMMIT_ID_SHORT $(git rev-parse --short=8 --verify HEAD)"


