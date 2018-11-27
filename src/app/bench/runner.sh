#!/usr/bin/env sh
export BENCHMARKS_RUNNER=TRUE
export BENCH_LIB=dune_bench
export CONSENSUS_MECHANISM=PROOF_OF_STAKE
exec dune exec -- ./main.exe -run-without-cross-library-inlining "$@"
