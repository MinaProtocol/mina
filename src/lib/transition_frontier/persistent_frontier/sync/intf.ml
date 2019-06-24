open Core_kernel
open Coda_base

module type Db_schema_intf = sig
  type external_transition_validated

  type state_hash

  type scan_state

  type pending_coinbases

  type root_data

  type _ t =
    | Transition : state_hash -> external_transition_validated t
    | Arcs : state_hash -> state_hash list t
    | Root : root_data t

  include Rocksdb.Serializable.GADT.Key_intf with type 'a t := 'a t
end

module type Db_intf = sig
  type external_transition_validated

  type scan_state

  type root_data

  type frontier_hash

  type t

  val create :
       directory:string
    -> t

  val check :
       t
    -> (unit, [`Not_initialized | `Corrupt]) Result.t

  val initialize :
       t
    -> root_transition:external_transition_validated
    -> root_data:root_data
    -> base_hash:frontier_hash
    -> unit

  val add :
       t
    -> transition:(external_transition_validated, State_hash.t) With_hash.t
    -> unit Or_error.t

  val move_root :
       t
    -> new_root:root_data
    -> garbage:State_hash.t list
    -> State_hash.t Or_error.t

  val get_best_tip :
       t
    -> State_hash.t

  val set_best_tip :
       t
    -> State_hash.t
    -> State_hash.t

  val get_frontier_hash :
       t
    -> frontier_hash

  val set_frontier_hash :
       t
    -> frontier_hash
    -> unit
end

module type Inputs_with_db_intf = sig
  include Inputs.With_base_frontier

  module Db : Db_intf
    with type external_transition_validated := External_transition.Validated.t
     and type scan_state := Staged_ledger.Scan_state.t
     and type root_data := Frontier.Diff.root_data
     and type frontier_hash := Frontier.Hash.t
end

module type Worker_intf = sig
  type db

  type frontier_hash

  type e_lite_diff

  type create_args = {db: db; logger: Logger.t}

  include Otp_lib.Worker_supervisor.S
    with type create_args := create_args
     and type input := e_lite_diff list * frontier_hash
     and type output := unit Or_error.t
end

module type Inputs_with_worker_intf = sig
  include Inputs_with_db_intf

  module Worker : Worker_intf
    with type db := Db.t
     and type frontier_hash := Frontier.Hash.t
     and type e_lite_diff := Frontier.Diff.Lite.E.t
end
