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

(** [make ~name ?proof_cache_json setup] builds an Alcotest suite. [setup] is
    called once, to set up the suite and register its tests, in order, with
    [test].

    [proof_cache_json] is the contents of the suite's [proof_cache.json]. A
    suite without one generates its proofs, even when [ERROR_ON_PROOF] is set.

    When [PROOF_CACHE_OUT] names a directory, each suite with a proof cache
    writes its updated cache to [PROOF_CACHE_OUT/<name>.json] on exit.
*)
val make :
     name:string
  -> ?proof_cache_json:string
  -> (test:(string -> (unit -> unit) -> unit) -> unit)
  -> string * unit Alcotest.test_case list

(** [assert_true f] runs [f], failing if it returns [false], like a
    [let%test]. *)
val assert_true : (unit -> bool) -> unit -> unit
