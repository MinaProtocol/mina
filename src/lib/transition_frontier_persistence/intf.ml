open Protocols.Coda_transition_frontier
open Coda_base
open Async_kernel
open Pipe_lib

module type Transition_database_schema = sig
  type external_transition_validated

  type state_hash

  type scan_state

  type pending_coinbases

  type _ t =
    | Transition :
        state_hash
        -> (external_transition_validated * state_hash list) t
    | Root : (state_hash * scan_state * pending_coinbases) t

  include Rocksdb.Serializable.GADT.Key_intf with type 'a t := 'a t
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

module type Worker_inputs = sig
  include Transition_frontier.Inputs_intf

  module Transition_storage : sig
    module Schema :
      Transition_database_schema
      with type external_transition_validated :=
                  External_transition.Validated.Stable.Latest.t
       and type state_hash := State_hash.Stable.Latest.t
       and type scan_state := Staged_ledger.Scan_state.Stable.Latest.t
       and type pending_coinbases := Pending_coinbase.t

    include Rocksdb.Serializable.GADT.S with type 'a g := 'a Schema.t

    val get : t -> logger:Logger.t -> ?location:string -> 'a Schema.t -> 'a
  end

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type external_transition_validated := External_transition.Validated.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type user_command := User_command.t
     and type pending_coinbase := Pending_coinbase.t
     and type consensus_state := Consensus.Data.Consensus_state.Value.t
     and type consensus_local_state := Consensus.Data.Local_state.t
     and type verifier := Verifier.t
     and module Extensions.Work = Transaction_snark_work.Statement
end

module type Worker = sig
  type hash

  type diff

  type transition_storage

  type t

  val create : ?directory_name:string -> logger:Logger.t -> unit -> t

  val close : t -> unit

  val handle_diff : t -> hash -> diff -> hash

  module For_tests : sig
    val transition_storage : t -> transition_storage
  end
end

module type Main_inputs = sig
  include Worker_inputs

  module Make_worker (Inputs : Worker_inputs) : sig
    include
      Worker
      with type hash := Inputs.Transition_frontier.Diff_hash.t
       and type diff := Inputs.Transition_frontier.Diff_mutant.E.t
       and type transition_storage := Inputs.Transition_storage.t

    val handle_diff :
         t
      -> Inputs.Transition_frontier.Diff_hash.t
      -> Inputs.Transition_frontier.Diff_mutant.E.t
      -> Inputs.Transition_frontier.Diff_hash.t Deferred.Or_error.t
  end
end

module type S = sig
  type frontier

  type t

  type diff

  type diff_hash

  type root_snarked_ledger

  type consensus_local_state

  val create : ?directory_name:string -> logger:Logger.t -> unit -> t

  val listen_to_frontier_broadcast_pipe :
       logger:Logger.t
    -> frontier option Broadcast_pipe.Reader.t
    -> t
    -> unit Deferred.t

  val deserialize :
       directory_name:string
    -> logger:Logger.t
    -> trust_system:Trust_system.t
    -> root_snarked_ledger:root_snarked_ledger
    -> consensus_local_state:consensus_local_state
    -> frontier Deferred.t
end
