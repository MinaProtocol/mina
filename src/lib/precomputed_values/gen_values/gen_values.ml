[%%import
"../../../config.mlh"]

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
  val base_proof_expr : Parsetree.expression
end

module Dummy = struct
  let loc = Ppxlib.Location.none

  let base_proof_expr = [%expr Dummy_values.Tock.Bowe_gabizon18.proof]
end

module Make_real (Keys : Keys_lib.Keys.S) = struct
  let loc = Ppxlib.Location.none

  let base_proof_expr =
    let genesis = (Lazy.force Genesis_protocol_state.t).data in
    let base_proof =
      Keys.create_state_proof
        (Lazy.force Consensus.Data.Prover_state.precomputed_handler)
        genesis
        { previous_state= Lazy.force Protocol_state.negative_one
        ; proof= Snark_params.Tock.Proof.dummy
        ; update= Lazy.force Snark_transition.genesis }
      |> Or_error.ok_exn
    in
    assert (Keys.verify_state_proof genesis base_proof) ;
    [%expr
      Coda_base.Proof.Stable.V1.t_of_sexp
        [%e
          Ppx_util.expr_of_sexp ~loc
            (Coda_base.Proof.Stable.V1.sexp_of_t base_proof)]]
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
  let structure = [%str let base_proof = [%e M.base_proof_expr]] in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
