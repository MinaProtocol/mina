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
     and type ledger_diff_verified := Staged_ledger_diff.Verified.t
     and type staged_ledger := Staged_ledger.t

  module Transition_handler_validator :
    Transition_handler_validator_intf
    with type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type external_transition_verified := External_transition.Verified.t
     and type transition_frontier := Transition_frontier.t
     and type staged_ledger := Staged_ledger.t
     and type time := Block_time.t0

  module Network :
    Network_intf
    with type peer := Kademlia.Peer.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type host_and_port := Core.Host_and_port.t
     and type ancestor_proof_input := State_hash.t * int
     and type ancestor_proof := Ancestor.Proof.t
     and type protocol_state := External_transition.Protocol_state.value
end
