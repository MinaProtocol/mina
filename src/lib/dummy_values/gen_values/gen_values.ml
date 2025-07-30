open Ppxlib
open Core
open Async
open Pickles_types

let proof_string prev_width domain_log2 =
  let dummy = Pickles.Proof.dummy Nat.N2.n Nat.N2.n prev_width ~domain_log2 in
  Binable.to_string (module Pickles.Proof.Proofs_verified_2.Stable.Latest) dummy

let blockchain_proof_string = proof_string Nat.N2.n 16

let transaction_proof_string = proof_string Nat.N0.n 14

let str ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str
    let blockchain_proof () =
      Core_kernel.Binable.of_string
        (module Pickles.Proof.Proofs_verified_2.Stable.Latest)
        [%e estring blockchain_proof_string]

    let transaction_proof () =
      Core_kernel.Binable.of_string
        (module Pickles.Proof.Proofs_verified_2.Stable.Latest)
        [%e estring transaction_proof_string]]

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "dummy_values.ml")
  in
  let loc = Ppxlib.Location.none in
  Pprintast.top_phrase fmt (Ptop_def (str ~loc)) ;
  ignore (exit 0 : 'a Deferred.t)

let () =
  main () ;
  never_returns (Scheduler.go ())
