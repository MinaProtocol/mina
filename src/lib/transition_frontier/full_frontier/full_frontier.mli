(** This module is the core implementation of the in memory "full frontier".
 *  In this context, "full" refers to the fact that this frontier contains
 *  "fully expanded blockchain states" (i.e. [Breadcrumb]s). By comparison,
 *  the persistent frontier only contains "light blockchain states" (i.e.
 *  [Mina_block]s). This module is only concerned with the core
 *  data structure of the frontier, and is further wrapped with logic to
 *  integrate the core data structure with the various other concerns of
 *  the transition frontier (e.g. extensions, persistence, etc...) in the
 *  externally available [Transition_frontier] module.
 *)

open Mina_base
open Frontier_base
open Mina_state

include Frontier_intf.S

module Protocol_states_for_root_scan_state : sig
  type t = Protocol_state.value State_hash.With_state_hashes.t State_hash.Map.t

  val protocol_states_for_next_root_scan_state :
       t
    -> new_scan_state:Staged_ledger.Scan_state.t
    -> old_root_state:Protocol_state.value State_hash.With_state_hashes.t
    -> Protocol_state.value State_hash.With_state_hashes.t list
end

val create :
     logger:Logger.t
  -> root_data:Root_data.t
  -> root_ledger:Mina_ledger.Ledger.Any_ledger.witness
  -> consensus_local_state:Consensus.Data.Local_state.t
  -> max_length:int
  -> precomputed_values:Precomputed_values.t
  -> persistent_root_instance:Persistent_root.Instance.t
  -> time_controller:Block_time.Controller.t
  -> t

val persistent_root_instance : t -> Persistent_root.Instance.t

val close : loc:string -> t -> unit

val root_data : t -> Root_data.t

val calculate_diffs : t -> Breadcrumb.t -> Diff.Full.E.t list

val protocol_states_for_root_scan_state :
  t -> Protocol_states_for_root_scan_state.t

val apply_diffs :
     t
  -> Diff.Full.E.t list
  -> enable_epoch_ledger_sync:[ `Enabled of Mina_ledger.Ledger.Db.t | `Disabled ]
  -> has_long_catchup_job:bool
  -> [ `New_root_and_diffs_with_mutants of
       Root_identifier.t option * Diff.Full.With_mutant.t list ]

module For_tests : sig
  val equal : t -> t -> bool

  val find_protocol_state_exn :
    t -> State_hash.t -> Mina_state.Protocol_state.value

  val gen_breadcrumb :
       verifier:Verifier.t
    -> ?send_to_random_pk:bool
    -> unit
    -> (   Frontier_base.Breadcrumb.t
        -> Frontier_base.Breadcrumb.t Async_kernel.Deferred.t )
       Base_quickcheck.Generator.t

  val gen_breadcrumb_seq :
       verifier:Verifier.t
    -> int
    -> (   Frontier_base.Breadcrumb.t
        -> Frontier_base.Breadcrumb.t list Async_kernel.Deferred.t )
       Base_quickcheck.Generator.t

  val create_frontier : unit -> t

  val clean_up_persistent_root : frontier:t -> unit

  val verifier : unit -> Verifier.t

  val max_length : int
end
