#!/bin/bash

set -eo pipefail

# build print_versioned_types, then run Python script to compare versioned types in a pull request
source ~/.profile && \
    (dune build --profile=dev src/lib/ppx_version/tools/print_versioned_types.exe) && \
    ./scripts/compare_pr_diff_types.py ${BASE_BRANCH_NAME:-develop}
