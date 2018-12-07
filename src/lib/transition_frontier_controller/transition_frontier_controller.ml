open Protocols.Coda_pow
open Protocols.Coda_transition_frontier
open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  include Sync_handler.Inputs_intf

  module Time : Time_intf

  (*
    module Time : Time_intf

  module Consensus_mechanism :
    Consensus_mechanism_intf with type protocol_state_hash := State_hash.t

  module External_transition :
    External_transition_intf
    with type protocol_state := Consensus_mechanism.Protocol_state.value
     and type staged_ledger_diff := Consensus_mechanism.staged_ledger_diff
     and type protocol_state_proof := Consensus_mechanism.protocol_state_proof

  module Staged_ledger_diff : Staged_ledger_diff_intf

  module Merkle_address : Merkle_address.S

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t

  module Proof : sig
    type t
  end

  module Sok_message :
    Sok_message_intf with type public_key_compressed := Public_key.Compressed.t

  module Ledger_proof_statement :
    Ledger_proof_statement_intf with type ledger_hash := Frozen_ledger_hash.t

  module Ledger_proof :
    Ledger_proof_intf
    with type ledger_hash := Frozen_ledger_hash.t
     and type statement := Ledger_proof_statement.t
     and type proof := Proof.t
     and type sok_digest := Sok_message.Digest.t

  module Staged_ledger_aux_hash : Staged_ledger_aux_hash_intf

  module Transaction_snark_work :
    Transaction_snark_work_intf
    with type proof := Ledger_proof.t
     and type statement := Ledger_proof_statement.t
     and type public_key := Public_key.Compressed.t

  module Transaction_snark_scan_state :
    Transaction_snark_scan_state_intf
    with type ledger := Ledger.t
     and type transaction_snark_work := Transaction_snark_work.t
     and type ledger_proof := Ledger_proof.t
     and type sparse_ledger := Sparse_ledger.t
     and type ledger_proof_statement := Ledger_proof_statement.t
     and type transaction := Transaction.t
     and type transaction_with_info := Ledger.Undo.t
     and type frozen_ledger_hash := Frozen_ledger_hash.t
     and type sok_message := Sok_message.t
     and type staged_ledger_aux_hash := Staged_ledger_aux_hash.t

  module Staged_ledger :
    Staged_ledger_intf
    with type diff := Staged_ledger_diff.t
     and type valid_diff :=
                Staged_ledger_diff.With_valid_signatures_and_proofs.t
     and type staged_ledger_hash := Staged_ledger_hash.t
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
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t

  type ledger_database

  type ledger_diff
  *)
  module Sync_handler :
    Sync_handler_intf
    with type addr := Ledger.Addr.t
     and type hash := State_hash.t
     and type syncable_ledger := Syncable_ledger.t
     and type syncable_ledger_query := Syncable_ledger.query
     and type syncable_ledger_answer := Syncable_ledger.answer
     and type transition_frontier := Transition_frontier.t
     and type ancestor_proof := State_body_hash.t list

  module Transition_handler :
    Transition_handler_intf
    with type time_controller := Time.Controller.t
     and type external_transition := External_transition.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type time := Time.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t

  module Catchup :
    Catchup_intf
    with type external_transition := External_transition.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_controller_intf
  with type time_controller := Inputs.Time.Controller.t
   and type external_transition := Inputs.External_transition.t
   and type syncable_ledger_query := Inputs.Syncable_ledger.query
   and type syncable_ledger_answer := Inputs.Syncable_ledger.answer
   and type transition_frontier := Inputs.Transition_frontier.t
   and type time := Inputs.Time.t
   and type state_hash := State_hash.t = struct
  open Inputs

  let run ~logger ~time_controller ~frontier ~transition_reader
      ~sync_query_reader ~sync_answer_writer =
    let logger = Logger.child logger "transition_frontier_controller" in
    let valid_transition_reader, valid_transition_writer =
      Strict_pipe.create (Buffered (`Capacity 10, `Overflow Drop_head))
    in
    let catchup_job_reader, catchup_job_writer =
      Strict_pipe.create (Buffered (`Capacity 5, `Overflow Drop_head))
    in
    let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
      Strict_pipe.create (Buffered (`Capacity 3, `Overflow Crash))
    in
    Transition_handler.Validator.run ~frontier ~transition_reader
      ~valid_transition_writer ~logger ;
    Transition_handler.Processor.run ~logger ~time_controller ~frontier
      ~valid_transition_reader ~catchup_job_writer ~catchup_breadcrumbs_reader ;
    Catchup.run ~frontier ~catchup_job_reader ~catchup_breadcrumbs_writer ;
    Sync_handler.run ~sync_query_reader ~sync_answer_writer ~frontier
end
