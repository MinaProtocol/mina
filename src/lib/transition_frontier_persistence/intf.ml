open Protocols.Coda_transition_frontier
open Coda_base
open Async_kernel

module type Transition_database_schema = sig
  type external_transition

  type state_hash

  type scan_state

  type _ t =
    | Transition : state_hash -> (external_transition * state_hash list) t
    | Root : (state_hash * scan_state) t

  include Rocksdb.Serializable.GADT.Key_intf with type 'a t := 'a t
end

module type Base_inputs = sig
  include Transition_frontier.Inputs_intf

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
     and type diff_mutant := Diff_mutant.e
     and module Extensions.Work = Transaction_snark_work.Statement
end

module type Worker_inputs = sig
  include Base_inputs

  module Transition_storage : sig
    module Schema :
      Transition_database_schema
      with type external_transition := External_transition.Stable.Latest.t
       and type state_hash := State_hash.Stable.Latest.t
       and type scan_state := Staged_ledger.Scan_state.Stable.Latest.t

    include Rocksdb.Serializable.GADT.S with type 'a g := 'a Schema.t
  end
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

module type Worker = sig
  type external_transition

  type scan_state

  type state_hash

  type frontier

  type root_snarked_ledger

  type transition_storage

  type hash

  type 'a diff

  type t

  val create :
       logger:Logger.t
    -> root_snarked_ledger:root_snarked_ledger
    -> transition_storage:transition_storage
    -> t

  val deserialize :
    t -> consensus_local_state:Consensus.Local_state.t -> frontier Deferred.t

  val handle_diff : t -> hash -> 'a diff -> hash
end

(* TODO: Make an RPC_parallel version of Worker.ml *)
module type Main_inputs = sig
  include Base_inputs

  module Worker : sig
    type t

    val handle_diff :
      t -> Diff_hash.t -> 'a Diff_mutant.t -> Diff_hash.t Deferred.Or_error.t
  end
end
