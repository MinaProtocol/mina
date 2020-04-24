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

module Make_real
    (Keys : Keys_lib.Keys.S)
    (Protocol_state : Base_proof.Protocol_config) =
struct
  include Base_proof.Make (Keys) (Protocol_state)

  let loc = Ppxlib.Location.none

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
      ( module Make_real
                 (K)
                 (struct
                   let config = Runtime_config.compile_config.protocol

                   (* TODO: Uniquely identify by root hash. *)
                   module Genesis_ledger = struct
                     let t = Genesis_ledger.t
                   end

                   let protocol_state_with_hash =
                     Genesis_protocol_state.t ~genesis_ledger:Genesis_ledger.t
                       ~runtime_config:Runtime_config.compile_config
                 end)
      : S )
  in
  let structure =
    [%str
      let unit_test_base_hash = [%e Dummy.base_hash_expr]

      let unit_test_base_proof = [%e Dummy.base_proof_expr]

      let compile_base_hash = [%e M.base_hash_expr]

      let compile_base_proof = [%e M.base_proof_expr]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
