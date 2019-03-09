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
     and type consensus_local_state := Consensus.Local_state.t
     and type user_command := User_command.t
end

module With_unprocessed_transition_cache = struct
  module type S = sig
    include S

    module Unprocessed_transition_cache :
      Cache_lib.Intf.Transmuter_cache.S
      with module Cached := Cache_lib.Cached
       and module Cache := Cache_lib.Cache
       and type source =
                  (External_transition.Verified.t, State_hash.t) With_hash.t
       and type target = State_hash.t
  end
end
