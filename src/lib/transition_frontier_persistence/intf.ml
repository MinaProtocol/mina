open Protocols.Coda_transition_frontier
open Coda_base
open Async_kernel
open Pipe_lib

module type Transition_database_schema = sig
  type external_transition

  type state_hash

  type scan_state

  type _ t =
    | Transition : state_hash -> (external_transition * state_hash list) t
    | Root : (state_hash * scan_state) t

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

  module Make_transition_storage (Inputs : Transition_frontier.Inputs_intf) : sig
    module Schema :
      Transition_database_schema
      with type external_transition :=
                  Inputs.External_transition.Stable.Latest.t
       and type state_hash := State_hash.Stable.Latest.t
       and type scan_state := Inputs.Staged_ledger.Scan_state.Stable.Latest.t

    include Rocksdb.Serializable.GADT.S with type 'a g := 'a Schema.t

    val get : t -> logger:Logger.t -> ?location:string -> 'a Schema.t -> 'a
  end

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
     and type diff_mutant :=
                ( External_transition.Stable.Latest.t
                , State_hash.Stable.Latest.t )
                With_hash.t
                Diff_mutant.E.t
     and module Extensions.Work = Transaction_snark_work.Statement
end

module type Worker = sig
  type hash

  type diff

  type t

  val create : ?directory_name:string -> logger:Logger.t -> unit -> t

  val close : t -> unit

  val handle_diff : t -> hash -> diff -> hash
end

(* TODO: Make an RPC_parallel version of Worker.ml *)
module type Main_inputs = sig
  include Worker_inputs

  module Make_worker (Inputs : Worker_inputs) : sig
    include
      Worker
      with type hash := Inputs.Diff_hash.t
       and type diff := State_hash.t Inputs.Diff_mutant.E.t

    val handle_diff :
         t
      -> Inputs.Diff_hash.t
      -> State_hash.t Inputs.Diff_mutant.E.t
      -> Inputs.Diff_hash.t Deferred.Or_error.t
  end
end

module type S = sig
  type frontier

  type t

  type 'output diff

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
    -> root_snarked_ledger:root_snarked_ledger
    -> consensus_local_state:consensus_local_state
    -> frontier Deferred.t
end
