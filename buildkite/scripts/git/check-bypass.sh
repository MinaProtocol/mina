#!/usr/bin/env bash

# Git Bypass Check Script
#
# This script checks if a pull request has been bypassed for certain CI checks
# by authorized users through GitHub comments.
#
# DESCRIPTION:
#   Verifies if a PR contains a bypass comment (e.g., !ci-bypass-changelog)
#   made by users who are eligible to bypass CI checks. Uses a Python script
#   to interact with GitHub API and check for the presence of bypass comments.
#
# USAGE:
#   ./check-bypass.sh <bypass_phrase>
#
# ARGUMENTS:
#   bypass_phrase - The comment phrase to look for (e.g., "!ci-bypass-changelog")
#
# ENVIRONMENT VARIABLES:
#   BUILDKITE_PULL_REQUEST - Pull request number (set by Buildkite)
#
# EXIT CODES:
#   0 - PR is bypassed, skip the check
#   1 - Error occurred during bypass check
#   (continues execution if PR is not bypassed)
#
# DEPENDENCIES:
#   - Python 3
#   - pip packages from scripts/github/github_info/requirements.txt
#   - scripts/github/github_info Python module
#
# AUTHORIZED USERS:
#   Only users listed in GITHUB_USERS_ELIGIBLE_FOR_BYPASS can bypass checks

GITHUB_USERS_ELIGIBLE_FOR_BYPASS="amc-ie deepthiskumar Trivo25 45930 SanabriaRusso nicc georgeee dannywillems cjjdespres"

BYPASS_PHRASE=$1


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