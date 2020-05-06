open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Async

let proof_string =
  let open Pickles_types in
  let module Proof = Pickles.Proof.Make (Nat.N2) (Nat.N2) in
  let dummy = Pickles.Proof.dummy Nat.N2.n Nat.N2.n in
  Binable.to_string (module Proof) dummy

let proof ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%stri
    let proof =
      let open Pickles_types in
      let module Proof = Pickles.Proof.Make (Nat.N2) (Nat.N2) in
      Core_kernel.Binable.of_string (module Proof) [%e estring proof_string]]

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "dummy_values.ml")
  in
  let loc = Ppxlib.Location.none in
  Pprintast.top_phrase fmt (Ptop_def [proof ~loc]) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
