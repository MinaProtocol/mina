[%%import
"../../../config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core

(* TODO: refactor to do compile time selection *)
[%%if
with_snark]

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

  let base_proof_expr = [%expr Dummy_values.Tock.proof]
end

module Make_real (Keys : Keys_lib.Keys.S) = struct
  let loc = Ppxlib.Location.none

  let base_hash =
    Keys.Step.instance_hash Keys.Consensus_mechanism.genesis_protocol_state

  let base_hash_expr =
    [%expr
      Snark_params.Tick.Field.t_of_sexp
        [%e
          Ppx_util.expr_of_sexp ~loc
            (Snark_params.Tick.Field.sexp_of_t base_hash)]]

  let wrap hash proof =
    let open Snark_params in
    let module Wrap = Keys.Wrap in
    Tock.prove
      (Tock.Keypair.pk Wrap.keys)
      Wrap.input {Wrap.Prover_state.proof} Wrap.main
      (Wrap_input.of_tick_field hash)

  let base_proof_expr =
    let open Snark_params in
    let prover_state =
      { Keys.Step.Prover_state.prev_proof= Tock.Proof.dummy
      ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
      ; prev_state= Keys.Consensus_mechanism.Protocol_state.negative_one
      ; update= Keys.Consensus_mechanism.Snark_transition.genesis }
    in
    let tick =
      Tick.prove
        (Tick.Keypair.pk Keys.Step.keys)
        (Keys.Step.input ()) prover_state Keys.Step.main base_hash
    in
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
      let module Consensus_mechanism =
      Consensus.Proof_of_signature.Make (struct
        module Time = Coda_base.Block_time
        module Proof = Coda_base.Proof
        module Genesis_ledger = Genesis_ledger

        let proposal_interval = Time.Span.of_ms @@ Int64.of_int 5000

        let private_key = None

        module Ledger_builder_diff = Ledger_builder.Make_diff (struct
          open Signature_lib
          open Coda_base
          module Compressed_public_key = Public_key.Compressed

          module Transaction = struct
            include (
              Transaction :
                module type of Transaction
                with module With_valid_signature := Transaction
                                                    .With_valid_signature )

            let receiver _ = failwith "stub"

            let sender _ = failwith "stub"

            let fee _ = failwith "stub"

            let compare _ _ = failwith "stub"

            module With_valid_signature = struct
              include Transaction.With_valid_signature

              let compare _ _ = failwith "stub"
            end
          end

          module Ledger_proof = Transaction_snark

          module Completed_work = struct
            include Ledger_builder.Make_completed_work
                      (Compressed_public_key)
                      (Ledger_proof)
                      (Transaction_snark.Statement)

            let check _ _ = failwith "stub"
          end

          module Ledger_hash = struct
            include Ledger_hash.Stable.V1

            let to_bytes = Ledger_hash.to_bytes
          end

          module Ledger_builder_aux_hash = struct
            include Ledger_builder_hash.Aux_hash.Stable.V1

            let of_bytes = Ledger_builder_hash.Aux_hash.of_bytes
          end

          module Ledger_builder_hash = struct
            include Ledger_builder_hash.Stable.V1

            let of_aux_and_ledger_hash =
              Ledger_builder_hash.of_aux_and_ledger_hash
          end
        end)
      end) in
      let module Keys = Keys_lib.Keys.Make (Consensus_mechanism) in
      let%map (module K) = Keys.create () in
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
