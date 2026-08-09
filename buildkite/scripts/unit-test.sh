#!/bin/bash

set -eo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <dune-profile> <path-to-source-tests>"
    exit 1
fi

export DUNE_PROFILE=$1
export MINA_PROFILE=$DUNE_PROFILE
path=$2

# shellcheck disable=SC1090
source ~/.profile

export MINA_LIBP2P_PASS="naughty blue worm"
export NO_JS_BUILD=1 # skip some JS targets which have extra implicit dependencies
export LAGRANGE_CACHE_DIR="/tmp/lagrange-cache"

# Allow core dumps.
#
# Both failure paths below already call scripts/link-coredumps.sh, which
# collects core.<pid>.* into core_dumps/ for the artifact upload, but nothing
# ever raised the core-file limit, so the tests ran with the container default
# of 0 and no core file was ever written.
#
# A test that dies in C code produces no OCaml output at all. In nightly build
# 1579 the src/lib/lmdb_storage test printed the name of its second case and
# then vanished, on the first run and again on the retry; core_dumps/ was
# empty, so there was nothing left to diagnose. Raising the limit costs nothing
# on a passing run.
ulimit -c unlimited 2>/dev/null || echo "could not raise the core file limit"
echo "core file limit: $(ulimit -c), core_pattern: $(cat /proc/sys/kernel/core_pattern 2>/dev/null || echo unknown)"

echo "--- Make libp2p helper"
export LIBP2P_NIXLESS=1 PATH=/usr/lib/go/bin:$PATH GO=/usr/lib/go/bin/go
time make libp2p_helper

# Turn on the proof-cache assertion, so that CI will fail if the proofs need to
# be updated.
export ERROR_ON_PROOF=true


# When coverage instrumentation is enabled and this is not a PR build (i.e. nightly),
# force full recompilation so bisect_ppx generates .coverage files for all source files,
# not just changed ones. Without --force, dune's incremental compilation skips unchanged
# files, leading to incomplete and inconsistent coverage reports across builds.
# A clean is needed before --force to avoid symlink race conditions where parallel
# rebuilds of shared dependencies (e.g. Rust/kimchi) collide on stale build artifacts.
FORCE_FLAG=""
# Note: We check BUILDKITE_PULL_REQUEST rather than BUILDKITE because both PR
# and nightly builds run under Buildkite. We only want --force on nightlies —
# forcing full recompilation on every PR build would waste CI time.
if [ -n "${DUNE_INSTRUMENT_WITH}" ] && [ "${BUILDKITE_PULL_REQUEST:-false}" = "false" ]; then
    echo "--- Coverage instrumentation detected on non-PR build, forcing full recompilation"
    echo "--- Cleaning build directory to avoid symlink races under --force"
    dune clean
    FORCE_FLAG="--force"
fi

# Note: By attempting a re-run on failure here, we can avoid rebuilding and
# skip running all of the tests that have already succeeded, since dune will
# only retry those tests that failed. Do not pass --force to the retry: it
# forces Dune to rerun the whole test suite, including tests that already passed.
echo "--- Run unit tests"
time dune runtest ${FORCE_FLAG} "${path}" || \
(./scripts/link-coredumps.sh && \
 echo "--- Retrying failed unit tests" && \
 time dune runtest "${path}" || \
 (./scripts/link-coredumps.sh && false))
