#!/usr/bin/env bash
rm -rf _build
for DIR in $(find ./src -name proof_cache.json | sed 's/\/proof_cache.json//'); do
  # Initialize the target file
  echo [] > $DIR/proof_cache_new.json;
  # Stage the new file for a git commit
  # Generate the cache file by running the tests
  PROOF_CACHE_OUT=$PWD/$DIR/proof_cache_new.json dune runtest $DIR;
  # Re-run the tests using the cache. Throws an error if the test is
  # non-deterministic and caused a cache miss.
  mv $PWD/$DIR/proof_cache_new.json $PWD/$DIR/proof_cache.json
  git add $PWD/$DIR/proof_cache.json
  ERROR_ON_PROOF=true dune runtest $DIR;
done
