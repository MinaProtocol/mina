open Protocols.Coda_pow
open Coda_base

module type S = sig
  include Transition_frontier.Inputs_intf

  val max_length : int

  module Transition_storage :
    Key_value_database.S
    with type key := State_hash.t
     and type value := External_transition.Stable.Latest.t

  module Root_storage : Storage.With_checksum_intf with type location := string

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type consensus_local_state := Consensus.Local_state.t
     and type user_command := User_command.t
     and module Extensions.Work = Transaction_snark_work.Statement
end
