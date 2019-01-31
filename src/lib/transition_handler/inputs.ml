open Protocols.Coda_pow
open Coda_base

module type S = sig
  module Time : Time_intf

  include Transition_frontier.Inputs_intf

  module State_proof :
    Proof_intf
    with type input := Consensus.Protocol_state.value
     and type t := Proof.t

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger := Staged_ledger.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
end
