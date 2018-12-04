open Core_kernel
open Protocols.Coda_pow
open Coda_base
open Pipe_lib
open Signature_lib

module type Inputs_intf = sig
  module Consensus_mechanism :
    Consensus_mechanism_intf with type protocol_state_hash := State_hash.t

  module External_transition :
    External_transition_intf
    with type protocol_state := Consensus_mechanism.Protocol_state.value
     and type ledger_builder_diff := Consensus_mechanism.ledger_builder_diff
     and type protocol_state_proof := Consensus_mechanism.protocol_state_proof

  module Ledger_builder_diff : Ledger_builder_diff_intf

  module Merkle_address : Merkle_address.S

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t

  module Ledger_builder : Ledger_builder_intf
    with type diff := Ledger_builder_diff.t
     and type valid_diff :=
                Ledger_builder_diff.With_valid_signatures_and_proofs.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type ledger_hash := Ledger_hash.t
     and type frozen_ledger_hash := Frozen_ledger_hash.t
     and type public_key := Public_key.Compressed.t
     and type ledger := Ledger.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t

  module Ledger_diff : sig
    type t

    val empty : t
  end

  module Transition_frontier :
    Transition_frontier_intf
    with type external_transition := External_transition.t
     and type state_hash := State_hash.t
     and type ledger_database := Ledger.Db.t
     and type ledger_diff := Ledger_diff.t

  type ledger_database

  type transaction_snark_scan_state

  type ledger_diff

  type staged_ledger

  module Transition_handler :
    Transition_handler_intf
    with type external_transition := External_transition.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t

  module Catchup :
    Catchup_intf
    with type external_transition := External_transition.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t

  module Sync_handler :
    Sync_handler_intf
    with type addr := Merkle_address.t
     and type hash := State_hash.t
     and type syncable_ledger := Ledger.t
     and type transition_frontier := Transition_frontier.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_controller_intf
  with type external_transition := Inputs.External_transition.t
   and type syncable_ledger_query := Inputs.Syncable_ledger.query
   and type syncable_ledger_answer := Inputs.Syncable_ledger.answer
   and type transition_frontier := Inputs.Transition_frontier.t
   and type state_hash := State_hash.t = struct
  open Inputs
  open Consensus_mechanism

  let run ~genesis_transition ~transition_reader ~sync_query_reader
      ~sync_answer_writer ~logger =
    let valid_transition_reader, valid_transition_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
    in
    let catchup_job_reader, catchup_job_writer =
      Strict_pipe.create (Buffered (`Capacity 5, `Overflow Drop_head))
    in
    (* TODO: initialize transition frontier from disk *)
    let frontier =
      Transition_frontier.create
        ~root_transition:
          (With_hash.of_data genesis_transition
             ~hash_data:
               (Fn.compose Protocol_state.hash
                  External_transition.protocol_state))
        ~root_snarked_ledger:(
            Ledger.foldi Genesis_ledger.t ~init:(Ledger.Db.create ()) ~f:(fun _addr db account ->
            let key = Account.public_key account in
            ignore (Ledger.Db.get_or_create_account_exn db key account);
            db
            ) )
        ~root_transaction_snark_scan_state:Transition_frontier.Transaction_snark_scan_state.empty
        ~root_staged_ledger_diff:Ledger_builder_diff.empty
        ~logger
    in
    Transition_handler.Validator.run ~transition_reader
      ~valid_transition_writer ;
    Transition_handler.Processor.run ~valid_transition_reader
      ~catchup_job_writer ~frontier ;
    Catchup.run ~catchup_job_reader ~frontier ;
    Sync_handler.run ~sync_query_reader ~sync_answer_writer ~frontier
end
