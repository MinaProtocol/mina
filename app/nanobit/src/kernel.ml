open Coda_main

module Prod () =
  Make_kernel
    (Ledger_proof.Prod)
    (functor (Ledger_builder_diff : sig type t [@@deriving sexp, bin_io] end) ->
      Consensus.Proof_of_signature.Make (Nanobit_base.Proof) (Ledger_builder_diff))

module Debug () =
  Make_kernel
    (Ledger_proof.Debug)
    (functor (Ledger_builder_diff : sig type t [@@deriving sexp, bin_io] end) ->
      Consensus.Proof_of_signature.Make (Nanobit_base.Proof) (Ledger_builder_diff))
