#!/usr/bin/env bash
# state in _build can cause non-determinism in proof_caches
rm -rf _build
# Read the find output rather than looping over it word by word, so a path
# containing whitespace stays one path.
find ./src -name proof_cache.json -print0 | while IFS= read -r -d '' CACHE; do
  DIR="$(dirname "$CACHE")"
  # I'm not sure why but using proof_cache.json directly causes non-determinism
  # Initialize the target file
  echo [] > "$DIR/proof_cache_new.json"
  # Generate the cache file by running the tests
  PROOF_CACHE_OUT="$PWD/$DIR/proof_cache_new.json" dune runtest "$DIR"
  mv "$PWD/$DIR/proof_cache_new.json" "$PWD/$DIR/proof_cache.json"
  # Stage the new file for a git commit
  git add "$PWD/$DIR/proof_cache.json"
  # Re-run the tests using the cache. Throws an error if the test is
  # non-deterministic and caused a cache miss.
  ERROR_ON_PROOF=true dune runtest "$DIR"
done
