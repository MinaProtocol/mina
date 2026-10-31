#!/usr/bin/env bash
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <profile>  (dev, devnet, lightnet or mainnet)" >&2
  exit 1
fi
export MINA_PROFILE=$1

set -e

# The transaction snark test suites run in a single runner, and are named after
# their directories.
TESTS=src/lib/transaction_snark/test
RUNNER=$TESTS/runner

# state in _build can cause non-determinism in proof_caches
rm -rf _build

# Start each cache from empty, so that it only keeps the proofs its tests use.
for CACHE in "$TESTS"/*/proof_cache.json; do
  echo [] > "$CACHE"
done

OUT=$(mktemp -d)
dune build "$RUNNER/main.exe"
# Generate the caches by running the tests; each suite with a cache writes it
# to $OUT/<suite>.json.
(cd "_build/default/$RUNNER" && PROOF_CACHE_OUT=$OUT ./main.exe)

for CACHE in "$OUT"/*.json; do
  SUITE=$(basename "$CACHE" .json)
  mv "$CACHE" "$TESTS/$SUITE/proof_cache.json"
  # Stage the new file for a git commit
  git add "$TESTS/$SUITE/proof_cache.json"
done
rmdir "$OUT"

# Re-run the tests using the caches. Throws an error if a test is
# non-deterministic and caused a cache miss.
ERROR_ON_PROOF=true dune build "@$RUNNER/runtest"
