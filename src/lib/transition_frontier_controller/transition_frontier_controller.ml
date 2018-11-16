open Protocols.Coda_pow
open Coda_base

module type Inputs_intf = sig
  module Consensus_mechanism : Consensus_mechanism_intf

  module Merkle_address : Merkle_address.S

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Merkle_hash.t

  module Transition_frontier : Transition_frontier_intf

  module Transition_handler :
    Transition_handler_intf
    with type external_transition := Consensus_mechanism.External_transition.t
     and type transition_frontier := Transition_frontier.t

  module Catchup :
    Catchup_intf
    with type external_transition := Consensus_mechanism.External_transition.t
     and type transition_frontier := Transition_frontier.t

  module Sync_handler :
    Sync_handler_intf
    with type addr := Merkle_address.t
     and type hash := Merkle_hash.t
     and type syncable_ledger := Syncable_ledger.t
     and type syncable_ledger_query := Syncable_ledger.query
     and type syncable_ledger_answer := Syncable_ledger.answer
     and type transition_frontier := Transition_frontier.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_controller_intf
  with type external_transition :=
              Inputs.Consensus_mechanism.External_transition.t
   and type syncable_ledger_query := Inputs.Syncable_ledger.query
   and type syncable_ledger_answer := Inputs.Syncable_ledger.answer = struct
  open Inputs

  let run ~transition_reader ~sync_query_reader ~sync_answer_writer =
    let valid_transition_reader, valid_transition_writer =
      Linear_pipe.create ()
    in
    let catchup_job_reader, catchup_job_writer = Linear_pipe.create () in
    let frontier = Transition_frontier.create () in
    Transition_handler.Validator.run frontier ~transition_reader
      ~valid_transition_writer ;
    Transition_handler.Processor.run frontier ~valid_transition_reader
      ~catchup_job_writer ;
    Catchup.run frontier ~catchup_job_reader ;
    Sync_handler.run frontier ~sync_query_reader ~sync_answer_writer
end
