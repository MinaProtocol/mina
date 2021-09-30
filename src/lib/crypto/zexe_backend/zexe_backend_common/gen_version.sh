#!/bin/bash
set -e -o pipefail

marlin_commit_id=$(cd ../../marlin_plonk_bindings/stubs && cargo metadata | jq '.packages[] | select(.name == "commitment_dlog").id' | cut -d " " -f 3 | sed 's/"//')

echo "let marlin_repo_sha = \"$marlin_commit_id\"" >> "$1"
