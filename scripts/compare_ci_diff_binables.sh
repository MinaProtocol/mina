#!/bin/bash

if [ ! "$CI" = "true" ] || [ ! -f /.dockerenv ]; then
    echo `basename $0` "can run only in Circle CI"
    exit 1
fi

# cleanup if needed

git clean -dfx
rm -rf base

# build run_ppx_coda, then run Python script to compare binable functors in a pull request

source ~/.profile && \
    (dune build --profile=print_binable_functors src/lib/ppx_coda/run_ppx_coda.exe) && \
    ./scripts/compare_pr_diff_binables.py ${CIRCLE_PULL_REQUEST}
