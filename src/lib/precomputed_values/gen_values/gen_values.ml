open Ppxlib
open Core
open Async
open Mina_state

let use_dummy_values = String.equal Node_config.proof_level "full" |> not

module type S = sig
  val compiled_values : Genesis_proof.t Async.Deferred.t option
end

let hashes =
  lazy
    (let constraint_constants =
       Genesis_constants.Constraint_constants.compiled
     in
     let proof_level = Genesis_constants.Proof_level.compiled in
     let ts =
       Transaction_snark.constraint_system_digests ~constraint_constants ()
     in
     let bs =
       Blockchain_snark.Blockchain_snark_state.constraint_system_digests
         ~proof_level ~constraint_constants ()
     in
     ts @ bs )

let hashes_to_expr ~loc hashes =
  let open Ppxlib.Ast_builder.Default in
  elist ~loc
  @@ List.map hashes ~f:(fun (x, y) ->
         [%expr
           [%e estring ~loc x]
           , Core.Md5.of_hex_exn [%e estring ~loc (Core.Md5.to_hex y)]] )

let vk_id_to_expr ~loc vk_id =
  let open Ppxlib.Ast_builder.Default in
  [%expr
    let t =
      lazy
        (Core.Sexp.of_string_conv_exn
           [%e
             estring ~loc
               (Core.Sexp.to_string
                  (Pickles.Verification_key.Id.sexp_of_t vk_id) )]
           Pickles.Verification_key.Id.t_of_sexp )
    in
    fun () -> Lazy.force t]

module Inputs = struct
  let proof_level = Genesis_constants.Proof_level.compiled

  let constraint_constants = Genesis_constants.Constraint_constants.compiled

  let genesis_constants = Genesis_constants.compiled

  let genesis_epoch_data = Consensus.Genesis_epoch_data.compiled

  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:genesis_constants.protocol

  let protocol_state_with_hashes =
    let open Staged_ledger_diff in
    Genesis_protocol_state.t ~genesis_ledger:Test_genesis_ledger.t
      ~genesis_epoch_data ~constraint_constants ~consensus_constants
      ~genesis_body_reference
end

let main () =
  let open Ppxlib.Ast_builder.Default in
  let target = (Sys.get_argv ()).(1) in
  let fmt = Format.formatter_of_out_channel (Out_channel.create target) in
  let loc = Ppxlib.Location.none in
  let structure =
    [%str
      module T = Genesis_proof.T
      include T

      let for_unit_tests =
        lazy
          (let open Staged_ledger_diff in
          let protocol_state_with_hashes =
            Mina_state.Genesis_protocol_state.t
              ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
              ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
              ~constraint_constants:
                Genesis_constants.Constraint_constants.for_unit_tests
              ~consensus_constants:
                (Lazy.force Consensus.Constants.for_unit_tests)
              ~genesis_body_reference
          in
          { runtime_config = Runtime_config.default
          ; constraint_constants =
              Genesis_constants.Constraint_constants.for_unit_tests
          ; proof_level = Genesis_constants.Proof_level.for_unit_tests
          ; genesis_constants = Genesis_constants.for_unit_tests
          ; genesis_ledger = Genesis_ledger.for_unit_tests
          ; genesis_epoch_data = Consensus.Genesis_epoch_data.for_unit_tests
          ; genesis_body_reference
          ; consensus_constants = Lazy.force Consensus.Constants.for_unit_tests
          ; protocol_state_with_hashes
          ; constraint_system_digests =
              lazy [%e hashes_to_expr ~loc (Lazy.force hashes)]
          ; proof_data = None
          })

      let compiled_inputs =
        lazy
          (let open Staged_ledger_diff in
          let constraint_constants =
            Genesis_constants.Constraint_constants.compiled
          in
          let genesis_constants = Genesis_constants.compiled in
          let genesis_epoch_data = Consensus.Genesis_epoch_data.compiled in
          let consensus_constants =
            Consensus.Constants.create ~constraint_constants
              ~protocol_constants:genesis_constants.protocol
          in
          let protocol_state_with_hashes =
            Mina_state.Genesis_protocol_state.t
              ~genesis_ledger:Test_genesis_ledger.t ~genesis_epoch_data
              ~constraint_constants ~consensus_constants ~genesis_body_reference
          in
          { Genesis_proof.Inputs.runtime_config = Runtime_config.default
          ; constraint_constants
          ; proof_level = Genesis_constants.Proof_level.compiled
          ; genesis_constants
          ; genesis_ledger = (module Test_genesis_ledger)
          ; genesis_epoch_data
          ; genesis_body_reference
          ; consensus_constants
          ; protocol_state_with_hashes
          ; constraint_system_digests = [%e[%expr None]]
          ; blockchain_proof_system_id = [%e[%expr None]]
          })

      let compiled = [%e[%expr None]]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
