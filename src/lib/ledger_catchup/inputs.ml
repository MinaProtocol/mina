open Protocols.Coda_pow
open Protocols.Coda_transition_frontier
open Coda_base

module type S = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type consensus_local_state := Consensus.Local_state.t
     and type user_command := User_command.t

  module Unprocessed_transition_cache :
    Unprocessed_transition_cache_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t

  module Transition_handler_validator :
    Transition_handler_validator_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type unprocessed_transition_cache := Unprocessed_transition_cache.t
     and type transition_frontier := Transition_frontier.t
     and type staged_ledger := Staged_ledger.t
     and type time := Block_time.t0

  module Network :
    Network_intf
    with type peer := Network_peer.Peer.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type consensus_state := Consensus.Consensus_state.value
     and type state_body_hash := State_body_hash.t
     and type ledger_hash := Ledger_hash.t
     and type sync_ledger_query := Ledger.Location.Addr.t Syncable_ledger.query
     and type sync_ledger_answer := Sync_ledger.answer

  module Time : Time_intf

  module Protocol_state_validator :
    Protocol_state_validator_intf
    with type time := Time.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type external_transition_proof_verified :=
                External_transition.Proof_verified.t
     and type external_transition_verified := External_transition.Verified.t
end
