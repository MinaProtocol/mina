#!/usr/bin/env bash

set -e -o pipefail
if [ -z ${MARLIN_REPO_SHA+x} ]; then
    # we are nested 7 directories deep (_build/<context>/src/lib/crypto/kimchi_backend/common)
    git_root=$(git rev-parse --show-toplevel || echo ../../../../../../..)

    # Check for the existence of the 'mina' submodule
    mina_submodule=$(git submodule status | grep "mina" || true)

    base_dir=
    if [[ -n "$mina_submodule" ]]; then
        base_dir=src/mina/
    fi
    CARGO_LOCK="$git_root/${base_dir}src/lib/crypto/kimchi_bindings/stubs/Cargo.lock"
    PAT='git\+https://github\.com/o1-labs/proof-systems\.git\?rev=........'

    marlin_repo_sha=$(grep -m 1 -oE "$PAT" "$CARGO_LOCK" | grep -oE '[^=]*$')
else
    marlin_repo_sha=$(cut -b -8 <<< "$MARLIN_REPO_SHA")
fi

echo "let marlin_repo_sha = \"$marlin_repo_sha\"" >> "$1"
