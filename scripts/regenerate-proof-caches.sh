#!/usr/bin/env bash

for DIR in $(find -name proof_cache.json | sed 's/\/proof_cache.json//'); do
  # Initialize the target file
  echo [] > $DIR/proof_cache.json;
  # Stage the new file for a git commit
  git add -N $DIR/proof_cache.json;
  # Generate the cache file by running the tests
  PROOF_CACHE_OUT=$PWD/$DIR/proof_cache.json dune runtest $DIR;
  # Re-run the tests using the cache. Throws an error if the test is
  # non-deterministic and caused a cache miss.
  ERROR_ON_PROOF=true dune runtest $DIR;
done
