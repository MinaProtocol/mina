#!/bin/bash

# Archive-node end-to-end memory benchmark (CI runner)
#
# RunWithPostgres has already loaded src/app/archive/create_schema.sql into
# $PG_CONN. This builds archive_blocks and the bench, and runs the bench,
# which replays the zkApp-heavy corpus and writes an InfluxDB line-protocol
# perf file to /workdir for buildkite/scripts/bench/send.sh.
#
# Must be run from the repository root, inside the mina-toolchain image.

set -euo pipefail

if [[ ! -f dune-project ]]; then
    echo "Error: run from the repository root (where 'dune-project' exists)."
    exit 1
fi

perf_file="${PERF_OUTPUT_FILE:-/workdir/archive_memory_bench.perf}"
: "${PG_CONN:?PG_CONN must be set (provided by RunWithPostgres)}"

eval "$(opam config env)"
# the corpus was produced by a devnet-profile local network
export MINA_PROFILE=devnet

echo "Building archive_blocks and the benchmark..."
dune build src/app/archive_blocks/archive_blocks.exe \
    src/test/archive/archive_memory_bench/archive_memory_bench.exe

./_build/default/src/test/archive/archive_memory_bench/archive_memory_bench.exe \
    --uri "${PG_CONN}" \
    --variant "${MINA_BENCH_VARIANT:-ci}" \
    --git-branch "${BUILDKITE_BRANCH:-unknown}" \
    --git-commit "${BUILDKITE_COMMIT:-unknown}" \
    --influxdb-file "${perf_file}"
