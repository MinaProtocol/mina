(* module contains logic that may be shared across coordinator and worker. This
   is needed for backward compatibility reason. *)

open Core_kernel
open Async
open Mina_base
open Transaction_snark

(* NOTE:
   This is used in both Work_partitioner and Snark_worker for compatibility
   reasons
*)

module Zkapp_command_inputs = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        ( Zkapp_command_segment.Witness.Stable.V1.t
        * Zkapp_command_segment.Basic.Stable.V1.t
        * Statement.With_sok.Stable.V2.t )
        list
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t =
    ( Zkapp_command_segment.Witness.t
    * Zkapp_command_segment.Basic.t
    * Statement.With_sok.t )
    list

  let write_all_proofs_to_disk : Stable.V1.t -> t =
    List.map ~f:(fun (witness, segment, stmt) ->
        ( Zkapp_command_segment.Witness.write_all_proofs_to_disk witness
        , segment
        , stmt ) )

  let read_all_proofs_from_disk : t -> Stable.V1.t =
    List.map ~f:(fun (witness, segment, stmt) ->
        ( Zkapp_command_segment.Witness.read_all_proofs_from_disk witness
        , segment
        , stmt ) )
end

let extract_zkapp_segment_works ~m:(module M : S)
    ~(input : Mina_state.Snarked_ledger_state.t)
    ~(witness : Transaction_witness.t) ~(zkapp_command : Zkapp_command.t) :
    ( Zkapp_command_segment.Witness.t
    * Zkapp_command_segment.Basic.t
    * Statement.With_sok.t )
    list
    Deferred.Or_error.t =
  Or_error.try_with (fun () ->
      zkapp_command_witnesses_exn ~constraint_constants:M.constraint_constants
        ~global_slot:witness.block_global_slot
        ~state_body:witness.protocol_state_body
        ~fee_excess:Currency.Amount.Signed.zero
        [ ( `Pending_coinbase_init_stack witness.init_stack
          , `Pending_coinbase_of_statement
              { Pending_coinbase_stack_state.source =
                  input.source.pending_coinbase_stack
              ; target = input.target.pending_coinbase_stack
              }
          , `Sparse_ledger witness.first_pass_ledger
          , `Sparse_ledger witness.second_pass_ledger
          , `Connecting_ledger_hash input.connecting_ledger_left
          , zkapp_command )
        ]
      |> List.rev )
  |> Result.map_error ~f:(fun e ->
         Error.createf
           !"Failed to generate inputs for zkapp_command : %s: %s"
           (Zkapp_command.to_yojson zkapp_command |> Yojson.Safe.to_string)
           (Error.to_string_hum e) )
  |> Deferred.return
