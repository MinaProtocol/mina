open Coda_base
open Async_kernel
open Pipe_lib
open Coda_transition

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

  type add_transition = external_transition_verified

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
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * unit Truth.true_t
                , [`Proof] * unit Truth.true_t
                , [`Delta_transition_chain]
                  * State_hash.t Non_empty_list.t Truth.true_t
                , [`Frontier_dependencies] * unit Truth.true_t
                , [`Staged_ledger_diff] * unit Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t
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
      with type hash := Inputs.Transition_frontier.Diff.Hash.t
       and type diff := Inputs.Transition_frontier.Diff.Mutant.E.t
       and type transition_storage := Inputs.Transition_storage.t

    val handle_diff :
         t
      -> Inputs.Transition_frontier.Diff.Hash.t
      -> Inputs.Transition_frontier.Diff.Mutant.E.t
      -> Inputs.Transition_frontier.Diff.Hash.t Deferred.Or_error.t
  end
end

module type S = sig
  type frontier

  type t

  type verifier

  val create :
       ?directory_name:string
    -> logger:Logger.t
    -> flush_capacity:int
    -> max_buffer_capacity:int
    -> unit
    -> t

  val listen_to_frontier_broadcast_pipe :
    frontier option Broadcast_pipe.Reader.t -> t -> unit Deferred.t

  val deserialize :
       directory_name:string
    -> logger:Logger.t
    -> verifier:verifier
    -> trust_system:Trust_system.t
    -> root_snarked_ledger:Ledger.Db.t
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> frontier Deferred.t
end
