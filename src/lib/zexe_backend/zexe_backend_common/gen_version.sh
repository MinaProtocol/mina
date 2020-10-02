#!/bin/sh
set -e -o pipefail

marlin_submodule_dir=$(git submodule | grep marlin | cut -d' ' -f3)
marlin_repo_sha=$(cd $marlin_submodule_dir && git rev-parse --short=8 --verify HEAD)

echo "let marlin_repo_sha = \"$marlin_repo_sha\"" >> "$1"
