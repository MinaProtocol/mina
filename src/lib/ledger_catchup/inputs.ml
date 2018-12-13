open Protocols.Coda_transition_frontier
open Coda_base

module type S = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type ledger_database := Ledger.Db.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type ledger := Ledger.t

  module Network :
    Network_intf
    with type peer := Kademlia.Peer.t
     and type state_hash := State_hash.t
     and type transition := External_transition.t
end
