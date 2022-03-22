#!/usr/bin/env bash
set -e -o pipefail
if [ -z ${MARLIN_REPO_SHA+x} ]; then
    marlin_submodule_dir=$(git submodule status | grep marlin | sed 's/^[-\ ]//g' | cut -d ' ' -f 2)
    marlin_repo_sha=$(cd $marlin_submodule_dir && git rev-parse --short=8 --verify HEAD)
else
    marlin_repo_sha=$(cut -b -8 <<< "$MARLIN_REPO_SHA")
fi

echo "let marlin_repo_sha = \"$marlin_repo_sha\"" >> "$1"
