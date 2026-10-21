(** Run transaction snark test suites in a single process, so that they share
    the transaction snark keys instead of each generating them.

    Each suite keeps its own proof cache. Every test runs with that suite's
    proofs swapped into {!proof_cache}, and with the random state that
    [ppx_inline_test] gives its tests, so the witnesses (and so the cached
    proofs) don't depend on which other suites ran first.
*)

(** The proof cache shared by every suite in the process. Circuits that a
    suite compiles itself must be compiled with this cache. *)
val proof_cache : Pickles.Proof_cache.t

(** [make ~name ?proof_cache_json tests] builds an Alcotest suite. [tests] is
    called once, to set up the suite and return its test cases.

    [proof_cache_json] is the contents of the suite's [proof_cache.json]. A
    suite without one generates its proofs, even when [ERROR_ON_PROOF] is set.

    When [PROOF_CACHE_OUT] names a directory, each suite with a proof cache
    writes its updated cache to [PROOF_CACHE_OUT/<name>.json] on exit.
*)
val make :
     name:string
  -> ?proof_cache_json:string
  -> (unit -> unit Alcotest.test_case list)
  -> string * unit Alcotest.test_case list
