[%%import
"/src/config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Coda_state

(* TODO: refactor to do compile time selection *)
[%%if
proof_level = "full"]

let use_dummy_values = false

[%%else]

let use_dummy_values = true

[%%endif]

module type S = sig
  val base_hash_expr : Parsetree.expression

  val base_proof_expr : Parsetree.expression
end

module Dummy = struct
  let loc = Ppxlib.Location.none

  let base_hash_expr = [%expr Snark_params.Tick.Field.zero]

  let base_proof_expr = [%expr Dummy_values.Tock.Bowe_gabizon18.proof]
end

module Make_real (Keys : Keys_lib.Keys.S) = struct
  let loc = Ppxlib.Location.none

  let constraint_constants = Genesis_constants.Constraint_constants.compiled

  let genesis_constants = Genesis_constants.compiled

  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:genesis_constants.protocol

  let protocol_state_with_hash =
    Genesis_protocol_state.t ~genesis_ledger:Test_genesis_ledger.t
      ~constraint_constants ~consensus_constants

  let base_hash = Keys.Step.instance_hash protocol_state_with_hash.data

  let compiled_values =
    Genesis_proof.create_values
      ~keys:(module Keys : Keys_lib.Keys.S)
      { constraint_constants
      ; proof_level= Full
      ; genesis_constants
      ; genesis_ledger= (module Test_genesis_ledger)
      ; consensus_constants
      ; protocol_state_with_hash
      ; base_hash }

  let base_hash_expr =
    [%expr
      Snark_params.Tick.Field.t_of_sexp
        [%e
          Ppx_util.expr_of_sexp ~loc
            (Snark_params.Tick.Field.sexp_of_t base_hash)]]

  let base_proof_expr =
    [%expr
      Coda_base.Proof.Stable.V1.t_of_sexp
        [%e
          Ppx_util.expr_of_sexp ~loc
            (Coda_base.Proof.Stable.V1.sexp_of_t compiled_values.genesis_proof)]]
end

open Async

let main () =
  let target = Sys.argv.(1) in
  let fmt = Format.formatter_of_out_channel (Out_channel.create target) in
  let loc = Ppxlib.Location.none in
  let%bind (module M) =
    if use_dummy_values then return (module Dummy : S)
    else
      let%map (module K) = Keys_lib.Keys.create () in
      (module Make_real (K) : S)
  in
  let structure =
    [%str
      module T = Genesis_proof.T
      include T

      let unit_test_base_hash = Snark_params.Tick.Field.zero

      let unit_test_base_proof = Dummy_values.Tock.Bowe_gabizon18.proof

      let for_unit_tests =
        lazy
          (let protocol_state_with_hash =
             Coda_state.Genesis_protocol_state.t
               ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
               ~constraint_constants:
                 Genesis_constants.Constraint_constants.for_unit_tests
               ~consensus_constants:
                 (Lazy.force Consensus.Constants.for_unit_tests)
           in
           { constraint_constants=
               Genesis_constants.Constraint_constants.for_unit_tests
           ; proof_level= Genesis_constants.Proof_level.for_unit_tests
           ; genesis_constants= Genesis_constants.for_unit_tests
           ; genesis_ledger= Genesis_ledger.for_unit_tests
           ; consensus_constants= Lazy.force Consensus.Constants.for_unit_tests
           ; protocol_state_with_hash
           ; base_hash= unit_test_base_hash
           ; genesis_proof= unit_test_base_proof })

      let compiled_base_hash = [%e M.base_hash_expr]

      let compiled_base_proof = [%e M.base_proof_expr]

      let compiled =
        lazy
          (let constraint_constants =
             Genesis_constants.Constraint_constants.compiled
           in
           let genesis_constants = Genesis_constants.compiled in
           let consensus_constants =
             Consensus.Constants.create ~constraint_constants
               ~protocol_constants:genesis_constants.protocol
           in
           let protocol_state_with_hash =
             Coda_state.Genesis_protocol_state.t
               ~genesis_ledger:Test_genesis_ledger.t ~constraint_constants
               ~consensus_constants
           in
           { constraint_constants
           ; proof_level= Genesis_constants.Proof_level.compiled
           ; genesis_constants
           ; genesis_ledger= (module Test_genesis_ledger)
           ; consensus_constants
           ; protocol_state_with_hash
           ; base_hash= compiled_base_hash
           ; genesis_proof= compiled_base_proof })]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
