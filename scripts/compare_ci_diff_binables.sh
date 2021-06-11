#!/bin/bash

set -eo pipefail

if [ ! "$CI" = "true" ] || [ ! -f /.dockerenv ]; then
    echo `basename $0` "can run only in Circle CI"
    exit 1
fi

# cleanup if needed

git clean -dfx
rm -rf base

# FIXME: for debugging only
echo "OPAM SWITCH LIST"
opam switch list

echo "OPAM LIST"
opam list

# build print_binable_functors, then run Python script to compare binable functors in a pull request
source ~/.profile && \
    (dune build --profile=dev src/external/ppx_version/tools/print_binable_functors.exe) && \
    ./scripts/compare_pr_diff_binables.py ${BASE_BRANCH_NAME:-develop}
