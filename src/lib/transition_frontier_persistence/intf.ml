open Protocols.Coda_pow
open Coda_base
open Async_kernel

module type Inputs = sig
  include Transition_frontier.Inputs_intf

  val max_length : int

  module Transition_storage :
    Rocksdb.Serializable.S
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

module type Frontier_diff = sig
  type external_transition_verified

  type state_hash

  type scan_state

  type add_transition = (external_transition_verified, state_hash) With_hash.t

  type move_root =
    { best_tip: add_transition
    ; removed_transitions: state_hash list
    ; new_root: state_hash
    ; new_scan_state: scan_state }

  type t = Add_transition of add_transition | Move_root of move_root
end

module type S = sig
  type external_transition_verified

  type scan_state

  type state_hash

  type frontier

  type root_snarked_ledger

  type transition_storage

  type root_storage

  module Frontier_diff :
    Frontier_diff
    with type external_transition_verified := external_transition_verified
     and type state_hash := state_hash
     and type scan_state := scan_state

  type hash

  type t

  val create :
       logger:Logger.t
    -> root_snarked_ledger:root_snarked_ledger
    -> transition_storage:transition_storage
    -> root_storage:root_storage
    -> t

  val deserialize :
       t
    -> consensus_local_state:Consensus.Local_state.t
    -> frontier Deferred.Or_error.t

  val handle_diff : t -> hash -> Frontier_diff.t -> hash Deferred.Or_error.t
end
