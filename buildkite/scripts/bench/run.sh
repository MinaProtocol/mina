#!/bin/bash

set -eox pipefail

YELLOW_THRESHOLD="0.1"
RED_THRESHOLD="0.3"
EXTRA_ARGS="${EXTRA_ARGS:-}"
BRANCH="${BRANCH:-BUILDKITE_BRANCH}"

MAINLINE_BRANCHES="-m develop -m compatible -m master -m dkijania/bench_for_ledger_test"
while [[ "$#" -gt 0 ]]; do case $1 in
  heap-usage) BENCHMARK="heap-usage"; ;;
  mina-base) BENCHMARK="mina-base"; ;;
  archive)
    BENCHMARK="archive";
    EXTRA_ARGS="--no-run ${EXTRA_ARGS}"

  ;;
  ledger-export)
    BENCHMARK="ledger-export"
    EXTRA_ARGS="--genesis-ledger-path ./genesis_ledgers/devnet.json"
  ;;
  ledger-apply)
    BENCHMARK="ledger-apply"
  ;;
  snark)
    BENCHMARK="snark";
    K=1
    MAX_NUM_UPDATES=4
    MIN_NUM_UPDATES=2
    EXTRA_ARGS="--k ${K} --max-num-updates ${MAX_NUM_UPDATES} --min-num-updates ${MIN_NUM_UPDATES}"
  ;;
  zkapp) BENCHMARK="zkapp"; ;;
  --yellow-threshold) YELLOW_THRESHOLD="$2"; shift;;
  --red-threshold) RED_THRESHOLD="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

# The mina-base, heap-usage and zkapp micro-benchmarks each invoke a single
# self-contained test-suite executable with no genesis ledger, /etc/mina config
# or network -- so the freshly-built bare binary from the apps cache is enough,
# no .deb required. Map each to its cached exe and the name the python harness
# expects on PATH (mirroring what mina-test-suite installs). The other benches
# (archive: postgres DB; ledger-export/snark: genesis payload) still need the
# package, and any cache miss falls back to it too.
case "$BENCHMARK" in
  mina-base)  BARE_EXE=benchmarks.exe;   BARE_AS=mina-benchmarks ;;
  heap-usage) BARE_EXE=heap_usage.exe;   BARE_AS=mina-heap-usage ;;
  zkapp)      BARE_EXE=zkapp_limits.exe; BARE_AS=mina-zkapp-limits ;;
  *)          BARE_EXE="" ;;
esac

INSTALLED_BARE=false
if [[ -n "$BARE_EXE" ]]; then
  git config --global --add safe.directory /workdir
  source buildkite/scripts/export-git-env-vars.sh

  if ./buildkite/scripts/apps/restore_app.sh devnet "$BARE_EXE" "$BARE_AS"; then
    echo "Using bare $BARE_AS from apps cache (no .deb needed)"
    pip3 install -r scripts/benchmarks/requirements.txt
    INSTALLED_BARE=true
  fi
fi

if [[ "$INSTALLED_BARE" == false ]]; then
  source buildkite/scripts/bench/install.sh
fi

python3 ./scripts/benchmarks test --benchmark ${BENCHMARK}  --branch ${BRANCH} --tmpfile ${BENCHMARK}.csv --yellow-threshold $YELLOW_THRESHOLD --red-threshold $RED_THRESHOLD $MAINLINE_BRANCHES $EXTRA_ARGS
