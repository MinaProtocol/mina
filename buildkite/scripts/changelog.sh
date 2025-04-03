#!/bin/bash

# This script checks if a changelog entry is required for a given pull request.
# It compares the current commit with the base branch of the pull request and looks for changes
# in the specified trigger files. If changes are found, it checks if the required changelog entry
# is present. If not, it exits with an error. Can be bypassed by a !ci-bypass-changelog comment.

# Usage:
#   ./changelog.sh --path <path> --changelog-file <changelog-file>
#
# Options:
#   --path: Filepath for which to check the diff
#   --changelog-file: Location of changelog file (should be present if diff is non-empty)
#   -h, --help: Display help message
#
# Example:
#   ./changelog.sh --path 'src/daemon' --changelog-file 'changes/1234-new-feature.md'

BASE_PATH=""
CHANGELOG_FILE=""
# List of users who can bypass the changelog check by commenting !ci-bypass-changelog
# separated by space
GITHUB_USERS_ELIGIBLE_FOR_BYPASS="amc-ie mrmr1993 deepthiskumar Trivo25 45930 SanabriaRusso nicc georgeee"

BYPASS_PHRASE="!ci-bypass-changelog"

PIPELINE_SLUG="mina-o-1-labs"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --path) BASE_PATH="$2"; shift ;;
        --changelog-file) CHANGELOG_FILE="$2"; shift ;;
        -h|--help)  echo "Usage: $0 --path <path> --required-change <required-change>"; 
                    echo "";
                    echo "Options:";
                    echo "  --path: The trigger to look for in the diff"; 
                    echo "  --required-change: The required change to look for in the diff";
                    echo "Example:";
                    echo "  $0 --path 'src/daemon' --required-change 'changes/1234-new-feature.md'";
                    exit 0 ;;
        *) echo "❌  Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$BASE_PATH" ]]; then
    echo "❌  --path is not set"
    echo "❌  Did you forget to pass --path ?"
    echo "❌  See --help for more info"
    exit 1
fi
if [[ -z "$CHANGELOG_FILE" ]]; then
    echo "❌  --changelog-file is not set"
    echo "❌  Did you forget to pass ----changelog-file ?"
    echo "❌  See --help for more info"
    exit 1
fi

set -eou pipefail

source "./buildkite/scripts/refresh_code.sh"

# make sure we cleaned git
git clean -fd


if [[ $BUILDKITE_PIPELINE_SLUG != "$PIPELINE_SLUG" ]]; then
    echo "⏭️  Skipping run on non PR pipeline"
    exit 0
fi

if [[ ! "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" ]]; then 
    echo "❌  BUILDKITE_PULL_REQUEST_BASE_BRANCH env variable is not defined"
    echo "❌  Did you run this job not through '!ci-build-me' ?"
    exit 1
fi

# Check if PR is bypassed by a !ci-bypass-changelog comment
pip install -r scripts/github/github_info/requirements.txt

COMMENTED_CODE=0
(python3 scripts/github/github_info is_pr_commented --comment "$BYPASS_PHRASE" \
  --by $GITHUB_USERS_ELIGIBLE_FOR_BYPASS --pr "$BUILDKITE_PULL_REQUEST") \
   || COMMENTED_CODE=$?

if [[ "$COMMENTED_CODE" == 0 ]]; then
    echo "⏭️  Skipping run as PR is bypassed"
    exit 0
elif [[ "$COMMENTED_CODE" == 1 ]]; then
    echo "⚙️  PR is not bypassed. Proceeding with changelog check..."
else
    echo "❌ Failed to check PR for being eligible for changelog check bypass"
    exit 1
fi

REMOTE_BRANCH="${REMOTE}/${BUILDKITE_PULL_REQUEST_BASE_BRANCH}"

BASE_COMMIT=$(git log "${REMOTE_BRANCH}" -1 --pretty=format:%H)
echo "Diffing current commit: ${BUILDKITE_COMMIT} against branch: ${BUILDKITE_PULL_REQUEST_BASE_BRANCH} (${BASE_COMMIT})" >&2

if (git diff --quiet "${REMOTE_BRANCH}" "$BASE_PATH"); then
    echo "⏭️  No change in ${BASE_PATH} detected. Changelog does not need to be updated"
else
    if [[ -f "$CHANGELOG_FILE" ]]; then
        echo "✅  Changelog updated!"
    else
        echo "❌  Missing changelog entry detected !!"
        echo ""
        echo "This job detected that you modified important part of code and did not update changelog file."
        echo "Please ensure that you added this change to PR's changelog file: "
        echo "${CHANGELOG_FILE}"
        echo "It will help us to produce Release Notes for upcoming release"
        exit 1
    fi
fi
