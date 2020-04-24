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

  let protocol_state_with_hash =
    Genesis_protocol_state.t ~genesis_ledger:Test_genesis_ledger.t
      ~genesis_constants:Genesis_constants.compiled

  let base_hash = Keys.Step.instance_hash protocol_state_with_hash.data

  let base_hash_expr =
    [%expr
      Snark_params.Tick.Field.t_of_sexp
        [%e
          Ppx_util.expr_of_sexp ~loc
            (Snark_params.Tick.Field.sexp_of_t base_hash)]]

  let wrap hash proof =
    let open Snark_params in
    let module Wrap = Keys.Wrap in
    let input = Wrap_input.of_tick_field hash in
    let proof =
      Tock.prove
        (Tock.Keypair.pk Wrap.keys)
        Wrap.input {Wrap.Prover_state.proof} Wrap.main input
    in
    assert (Tock.verify proof (Tock.Keypair.vk Wrap.keys) Wrap.input input) ;
    proof

  let base_proof_expr =
    let open Snark_params in
    let prover_state =
      { Keys.Step.Prover_state.prev_proof= Tock.Proof.dummy
      ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
      ; prev_state=
          Protocol_state.negative_one ~genesis_ledger:Test_genesis_ledger.t
            ~protocol_constants:Genesis_constants.compiled.protocol
      ; genesis_state_hash= protocol_state_with_hash.hash
      ; expected_next_state= None
      ; update= Snark_transition.genesis ~genesis_ledger:Test_genesis_ledger.t
      }
    in
    let main x =
      Tick.handle
        (Keys.Step.main ~logger:(Logger.create ()) x)
        (Consensus.Data.Prover_state.precomputed_handler
           ~genesis_ledger:Test_genesis_ledger.t)
    in
    let tick =
      Tick.prove
        (Tick.Keypair.pk Keys.Step.keys)
        (Keys.Step.input ()) prover_state main base_hash
    in
    assert (
      Tick.verify tick
        (Tick.Keypair.vk Keys.Step.keys)
        (Keys.Step.input ()) base_hash ) ;
    let proof = wrap base_hash tick in
    [%expr
      Coda_base.Proof.Stable.V1.t_of_sexp
        [%e
          Ppx_util.expr_of_sexp ~loc
            (Coda_base.Proof.Stable.V1.sexp_of_t proof)]]
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
      let base_hash = [%e M.base_hash_expr]

      let base_proof = [%e M.base_proof_expr]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
