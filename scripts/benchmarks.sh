#!/bin/sh

# runs inline benchmarks
# requires that app/benchmarks/benchmarks.exe is built
# run with -help to see available flags

export BENCHMARKS_RUNNER=TRUE
export X_LIBRARY_INLINING=true

GIT_ROOT="`git rev-parse --show-toplevel`"

BENCHMARK_EXE=$GIT_ROOT/_build/default/src/app/benchmarks/benchmarks.exe

if [ ! -f "$BENCHMARK_EXE" ]; then
    echo "Please run 'make benchmarks' before running this script";
    exit 1
fi

exec $BENCHMARK_EXE "$@" -run-without-cross-library-inlining -suppress-warnings
