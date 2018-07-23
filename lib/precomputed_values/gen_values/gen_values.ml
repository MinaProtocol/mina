open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core

module type S = sig
  val base_hash_expr : Parsetree.expression
  val base_proof_expr : Parsetree.expression
end

module Dummy = struct
  let loc = Ppxlib.Location.none

  let base_hash_expr = [%expr Snark_params.Tick.Field.zero]

  let base_proof_expr = [%expr Dummy_values.Tock.proof]
end

module Make_real (Keys : Keys_lib.Keys.S) = struct
  let loc = Ppxlib.Location.none

  let base_hash = Keys.Step.instance_hash Blockchain_snark.Blockchain_state.zero

  let base_hash_expr =
    [%expr
      Snark_params.Tick.Field.t_of_sexp
        [%e Ppx_util.expr_of_sexp ~loc (Snark_params.Tick.Field.sexp_of_t base_hash) ]
    ]

  let wrap hash proof =
    let open Snark_params in
    let module Wrap = Keys.Wrap in
    Tock.prove
      (Tock.Keypair.pk Wrap.keys)
      (Wrap.input ()) {Wrap.Prover_state.proof} Wrap.main (embed hash)

  let base_proof_expr =
    let open Snark_params in
    let prover_state =
      { Keys.Step.Prover_state.prev_proof= Tock.Proof.dummy
      ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
      ; prev_state= Blockchain_snark.Blockchain_state.negative_one
      ; update= Blockchain_snark.Blockchain_state.genesis_block }
    in
    let tick =
      Tick.prove
        (Tick.Keypair.pk Keys.Step.keys)
        (Keys.Step.input ())
        prover_state
        Keys.Step.main base_hash
    in
    let proof = wrap base_hash tick in
    [%expr Nanobit_base.Proof.Stable.V1.t_of_sexp
              [%e Ppx_util.expr_of_sexp ~loc
                    (Nanobit_base.Proof.Stable.V1.sexp_of_t proof)]
    ]
end

open Async

let main () =
  let use_dummy_values = Nanobit_base.Insecure.key_generation in
  let target = Sys.argv.(1) in
  let fmt = Format.formatter_of_out_channel (Out_channel.create target) in
  let loc = Ppxlib.Location.none in
  let%bind (module M) =
    if use_dummy_values
    then return (module Dummy : S)
    else
      let%map (module K) = Keys_lib.Keys.create () in
      (module Make_real(K) : S)
  in
  let structure = 
    [%str
      let base_hash = [%e M.base_hash_expr]
      let base_proof = [%e M.base_proof_expr]
    ]
  in
  Pprintast.top_phrase fmt (Ptop_def structure);
  exit 0
;;

let () =
  don't_wait_for (main ());
  never_returns (Scheduler.go ())
;;
