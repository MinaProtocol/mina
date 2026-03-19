#!/usr/bin/env bash
set -eo pipefail

# state in _build can cause non-determinism in proof_caches
rm -rf _build

# Sort directories by path length descending (deepest first).
# This ensures subdirectories are processed before their parent directory.
# Without this, `dune runtest <parent>` runs subdirectory tests too (dune is
# recursive), caching their results. Then when the script processes
# subdirectories later, dune skips re-running them and their proof caches
# stay empty.
DIRS=$(find ./src -name proof_cache.json -exec dirname {} \; \
  | awk '{print length($0), $0}' | sort -rn | cut -d' ' -f2-)

# Phase 1: Generate proof caches into temporary files.
# By processing deepest-first, each `dune runtest $DIR` only runs that
# directory's own tests (subdirectory tests haven't been requested yet).
# When the parent directory is processed last, dune sees subdirectory tests
# are already cached and only runs the parent's own tests, so PROOF_CACHE_OUT
# receives only the parent's proofs.
for DIR in $DIRS; do
  echo "=== Generating cache for $DIR ==="
  # I'm not sure why but using proof_cache.json directly causes non-determinism
  echo [] > "$DIR/proof_cache_new.json"
  PROOF_CACHE_OUT="$PWD/$DIR/proof_cache_new.json" dune runtest "$DIR"
done

# Phase 2: All generation succeeded — atomically swap all caches into place.
for DIR in $DIRS; do
  mv "$PWD/$DIR/proof_cache_new.json" "$PWD/$DIR/proof_cache.json"
  git add "$PWD/$DIR/proof_cache.json"
done

# Phase 3: Verify all caches in a clean build.
# Dune doesn't track environment variables, so ERROR_ON_PROOF=true won't
# trigger a re-run with the cached results from phase 1. We must clean
# _build to force a fresh run.
rm -rf _build
for DIR in $DIRS; do
  echo "=== Verifying cache for $DIR ==="
  ERROR_ON_PROOF=true dune runtest "$DIR"
done
