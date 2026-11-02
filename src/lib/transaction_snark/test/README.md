# Tests for the transaction snark

This directory and its subdirectories contain tests for the transaction snark,
including consistency checks for the 'in snark' logic with the 'out of snark'
version used by block application, and tests for the 'merge' rule for combining
transaction snark statements in the scan state.

### Performance considerations

These tests are run on CI for any PR that changes the daemon OCaml code. As
such, the tests added here should add value for the time they take, and should
not take too long.

#### One runner

Every suite needs the transaction snark keys, which take ~17s to generate. The
suites therefore run as Alcotest suites in a single runner, `runner/main.exe`,
so that the keys are generated once. To add a suite:
* in its library, define
  ```ocaml
  let suite () =
    Transaction_snark_test_suite.make ~name:"<directory name>"
    @@ fun ~test ->
    let module _ = struct
      (* setup *)

      let () = test "description" @@ fun () -> (* test body *)
    end in
    ()
  ```
  depending on `transaction_snark_test_suite` (see `suite/`);
* add the library to `runner/dune`, and its `suite ()` to `runner/main.ml`.

Run a single suite with `./main.exe test <name>` from
`_build/default/src/lib/transaction_snark/test/runner`.

#### Caching proofs

The largest performance impact of these tests is the time spent generating
proofs; especially for zkApp transactions, where we generate merge proofs as
well as the transaction proofs. In order to mitigate this, pickles provides a
mode where it will generate the circuit witness, but skips the expensive proving
step, using a cache.

Each suite keeps its own cache in its directory's `proof_cache.json`. To give a
suite a cache:
* add an empty cache, `[]`, as `proof_cache.json` in its directory;
* build it into the library, by adding to its `dune` file
  ```
  (rule
   (target proof_cache_json.ml)
   (deps proof_cache.json)
   (action
    (with-stdout-to
     %{target}
     (progn
      (echo "let contents = {json|")
      (cat proof_cache.json)
      (echo "|json}\n")))))
  ```
* pass it to the suite, with
  `Transaction_snark_test_suite.make ~proof_cache_json:Proof_cache_json.contents`;
* compile any circuits the suite defines itself with
  `~proof_cache:Transaction_snark_test_suite.proof_cache`.

The runner swaps each suite's proofs into the cache around each of its tests.
A suite without a cache always generates its proofs, even when `ERROR_ON_PROOF`
is set.

To regenerate the caches, run `./scripts/regenerate-proof-cache.sh dev`. When
`PROOF_CACHE_OUT` names a directory, the runner writes each suite's updated cache
to `PROOF_CACHE_OUT/<name>.json`, and the script moves them into place.

The witnesses of a cached suite's tests, and so its cached proofs, must not
depend on which tests ran before them, in that suite or in others: each test
starts from the random state that `ppx_inline_test` would give it, but any other
state shared between tests can make the cache miss.

**In case an error *is* generated, you should not commit the cache before making
the test deterministic.**

If none of the updates generated an error, the results can be committed to the
repository, and future CI runs will benefit from the speed-up of using the
cached proofs.
