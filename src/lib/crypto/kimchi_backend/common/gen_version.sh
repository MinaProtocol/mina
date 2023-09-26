#!/usr/bin/env bash
set -e -o pipefail

git_root=$(git rev-parse --show-toplevel)
mina_submodule=$(git submodule status | grep "mina" || true)

if [ -z ${MARLIN_REPO_SHA+x} ]; then
    if [[ -n "$mina_submodule" ]]; then
        marlin_submodule_dir=$(git -C "$git_root/src/mina" submodule status | grep proof-systems | sed 's/^[-\ ]//g' | cut -d ' ' -f 2)
        marlin_repo_sha=$(git -C "$git_root/src/mina/$marlin_submodule_dir" rev-parse --short=8 --verify HEAD)
    else
        marlin_submodule_dir=$(git submodule status | grep proof-systems | sed 's/^[-\ ]//g' | cut -d ' ' -f 2)
        marlin_repo_sha=$(git -C "$marlin_submodule_dir" rev-parse --short=8 --verify HEAD)
    fi
else
    marlin_repo_sha=$(cut -b -8 <<< "$MARLIN_REPO_SHA")
fi

echo "let marlin_repo_sha = \"$marlin_repo_sha\"" >> "$1"
