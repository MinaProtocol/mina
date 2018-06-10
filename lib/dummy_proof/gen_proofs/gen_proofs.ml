open Ast_mapper
open Ast_helper
open Asttypes
open Parsetree
open Longident
open Core

open Async

let dummy_proof_string (module B : Snarky.Backend_intf.S) =
  let module Impl = Snarky.Snark.Make(B) in
  let open Impl in
  let proof =
    let exposing = Data_spec.([ Typ.field ]) in
    let main x = assert_equal x x in
    let keypair = generate_keypair main ~exposing in
    prove (Keypair.pk keypair) exposing () main Field.one
  in
  B.Proof.to_string proof

let main () =
  let loc = Ppxlib.Location.none in
  let fmt = Format.formatter_of_out_channel (Out_channel.create "dummy_proof.ml") in
  let module E = Ppxlib.Ast_builder.Make(struct let loc = loc end) in
  let open E in
  Pprintast.top_phrase fmt
    (Ptop_def
      [%str
        let tick =
          Crypto_params.Tick_curve.Proof.of_string
            [%e estring (dummy_proof_string (module Crypto_params.Tick_curve))]

        let tock =
          Crypto_params.Tock_curve.Proof.of_string
            [%e estring (dummy_proof_string (module Crypto_params.Tock_curve))]
      ]);
  exit 0
;;

let () =
  ignore (main ());
  never_returns (Scheduler.go ())
