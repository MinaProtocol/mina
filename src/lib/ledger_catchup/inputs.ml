open Protocols.Coda_transition_frontier
open Coda_base

module type S = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type ledger_database := Ledger.Db.t
     and type ledger_builder := Ledger_builder.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type ledger_diff := Ledger_builder_diff.t

  module Network : Network_intf with type peer := Kademlia.Peer.t
end
