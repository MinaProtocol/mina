# Tests for the transaction snark

This directory and its subdirectories contain tests for the transaction snark, including consistency checks for the 'in snark' logic with the 'out of snark' version used by block application, and tests for the 'merge' rule for combining transaction snark statements in the scan state.

### Performance considerations

These tests are run on CI for any PR that changes the daemon OCaml code. As such, the tests added here should add value for the time they take, and should not take too long.

#### Caching proofs

The largest performance impact of these tests is the time spent generating proofs; especially for zkApp transactions, where we generate merge proofs as well as the transaction proofs. In order to mitigate this, pickles provides a mode where it will generate the circuit witness, but skips the expensive proving step, using a cache.

The recommended way to enable this cache is:
* add the lines
  ```ocaml
    let proof_cache =
      Result.ok_or_failwith @@ Pickles.Proof_cache.of_yojson
      @@ Yojson.Safe.from_file "proof_cache.json"

    let () = Transaction_snark.For_tests.set_proof_cache proof_cache
  ```
  to the top of the first `%test_module` in the file, to load a proof cache from the `proof_cache.json` file in the directory;
* add the lines
  ```ocaml
    let () =
      match Sys.getenv_opt "PROOF_CACHE_OUT" with
      | Some path ->
          Yojson.Safe.to_file path @@ Pickles.Proof_cache.to_yojson proof_cache
      | None ->
          ()
  ```
  to the bottom of the last `%test_module` in the file, to output the updated proof cache to the path given in the `PROOF_CACHE_OUT` environment variable, when provided;
* update the `dune` file in the test directory to include the libraries
  ```
   ppx_deriving_yojson.runtime
   result
  ```
* update the same `dune` file's `inline_tests` stanza to include `(deps proof_cache.json)`, for example
  ```diff
  - (inline_tests (flags -verbose -show-counts))
  + (inline_tests (flags -verbose -show-counts) (deps proof_cache.json))
  ```

For a concrete example, see commit [61afcaee844d5966331ddaee11fd8820f6dc1c8a](https://github.com/MinaProtocol/mina/commit/61afcaee844d5966331ddaee11fd8820f6dc1c8a).

Then, to update the cache for a set of tests, we can run the tests to update their contents. For example, to update the tests in `delegate`, `app_state`, `token_symbol`, `permissions`, and `voting_for`, we can run:
```bash
for DIR in ./delegate ./app_state ./token_symbol ./permissions ./voting_for; do
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
```

**In case an error *is* generated, you should not commit the cache before making the test deterministic.**

If none of the updates generated an error, the results can be committed to the repository, and future CI runs will benefit from the speed-up of using the cached proofs.
