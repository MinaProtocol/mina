#!/bin/bash

# Archive-node end-to-end memory benchmark (CI runner)
#
# RunWithPostgres has already loaded src/app/archive/create_schema.sql into
# $PG_CONN. archive_blocks is installed from the apps cache by the job's
# restore step (APPS_BARE_BINARIES), so this script only builds the bench and
# runs it, against that binary. It replays the zkApp-heavy corpus and writes an InfluxDB line-protocol
# perf file to /workdir for buildkite/scripts/bench/send.sh. Its memory gate
# (--assert-bounded-statements) fails if the ingest session keeps preparing new
# statements; see buildkite/scripts/bench/memory-gate.sh for how CI reports it.
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

# The apps build of this commit is a dependency of the job; its archive_blocks
# was installed as mina-archive-blocks. A cache miss fails the job before this
# script runs, so there is no build fallback here.
archive_blocks=$(command -v mina-archive-blocks) || {
  echo "mina-archive-blocks is not installed; the apps cache restore did not run"
  exit 1
}

echo "Building the benchmark..."
dune build src/test/archive/archive_memory_bench/archive_memory_bench.exe

./buildkite/scripts/bench/memory-gate.sh run archive-memory-bench \
  ./_build/default/src/test/archive/archive_memory_bench/archive_memory_bench.exe \
    --archive-blocks "${archive_blocks}" \
    --uri "${PG_CONN}" \
    --assert-bounded-statements \
    --variant "${MINA_BENCH_VARIANT:-ci}" \
    --git-branch "${BUILDKITE_BRANCH:-unknown}" \
    --git-commit "${BUILDKITE_COMMIT:-unknown}" \
    --influxdb-file "${perf_file}"
