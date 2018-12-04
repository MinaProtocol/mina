open Core_kernel
open Protocols.Coda_pow
open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  module Consensus_mechanism :
    Consensus_mechanism_intf with type protocol_state_hash := State_hash.t

  module External_transition :
    External_transition_intf
    with type protocol_state := Consensus_mechanism.Protocol_state.value
     and type ledger_builder_diff := Consensus_mechanism.ledger_builder_diff
     and type protocol_state_proof := Consensus_mechanism.protocol_state_proof

  module Merkle_address : Merkle_address.S

  module Ledger_builder_diff : Ledger_builder_diff_intf

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t

  module Key : Merkle_ledger.Intf.Key

  module Account : Merkle_ledger.Intf.Account with type key := Key.t

  module Location : Merkle_ledger.Location_intf.S

  module Ledger_diff : sig
    type t

    val empty : t
  end

  module Any_base :
    Merkle_mask.Base_merkle_tree_intf.S
    with module Addr = Location.Addr
     and module Location = Location
     and type account := Account.t
     and type root_hash := Ledger_hash.t
     and type hash := Ledger_hash.t
     and type key := Key.t

  module Ledger_mask : sig
    include
      Merkle_mask.Masking_merkle_tree_intf.S
      with module Addr = Location.Addr
       and module Location = Location
       and module Attached.Addr = Location.Addr
       and type account := Account.t
       and type location := Location.t
       and type key := Key.t
       and type hash := Ledger_hash.t
       and type parent := Any_base.t

    val merkle_root : t -> Ledger_hash.t

    val apply : t -> Ledger_diff.t -> unit

    val commit : t -> unit
  end

  module Transition_frontier :
    Transition_frontier_intf
    with type external_transition := External_transition.t
     and type state_hash := State_hash.t
     and type ledger_database := Ledger.Db.t
     and type ledger_diff := Ledger_diff.t
     and type staged_ledger := Staged_ledger.t

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
     and type syncable_ledger := Syncable_ledger.t
     and type syncable_ledger_query := Syncable_ledger.query
     and type syncable_ledger_answer := Syncable_ledger.answer
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
        ~root_snarked_ledger:(Ledger.Db.of_ledger Genesis_ledger.t)
        ~root_transaction_snark_scan_state:Transaction_snark_scan_state.empty
        ~root_staged_ledger_diff:Ledger_diff.empty
        ~logger
    in
    Transition_handler.Validator.run ~transition_reader
      ~valid_transition_writer ;
    Transition_handler.Processor.run ~valid_transition_reader
      ~catchup_job_writer ~frontier ;
    Catchup.run ~catchup_job_reader ~frontier ;
    Sync_handler.run ~sync_query_reader ~sync_answer_writer ~frontier
end
