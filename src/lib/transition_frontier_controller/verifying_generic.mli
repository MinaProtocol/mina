open Mina_base
open Core_kernel

(** Summary of the state relevant to verifying generic functions  *)
type 'a data = { substate : 'a Substate_types.t; baton : bool }

module Make : functor
  (F : sig
     (** Result of processing *)
     type proceessing_result

     (** Resolve all gossips held in the state to [`Ignore] *)
     val ignore_gossip : Transition_state.t -> Transition_state.t

     (** Extract data from the state *)
     val to_data : Transition_state.t -> proceessing_result data option

     (** Update state witht the given data *)
     val update :
       proceessing_result data -> Transition_state.t -> Transition_state.t
   end)
  -> sig
  (** Collect transitions that are either in [Substate.Processing Substate.Dependent]
      or in [Substate.Failed] statuses and set [baton] to [true] for the next
      ancestor in [Substate.Processing (Substate.In_progress _)] status.
      
      Traversal starts with a transition represented by its state and the state is also
      included into result (or has [baton] set to [true]) if it satisfies the conditions.
        
      Function does nothing and returns [[]] if [F.to_data] returns [Nothing] on provided state.
      *)
  val collect_dependent_and_pass_the_baton :
       transition_states:Transition_state.t State_hash.Table.t
    -> dsu:Processed_skipping.Dsu.t
    -> Transition_state.t
    -> Transition_state.t list

  (** Collect transitions that are either in [Substate.Processing Substate.Dependent]
      or in [Substate.Failed] statuses and set [baton] to [true] for the next
      ancestor in [Substate.Processing (Substate.In_progress _)] status.
      
      Traversal starts with a transition represented by its state hash and the state is also
      included into result (or has [baton] set to [true]) if it satisfies the conditions.
        
      Function does nothing and returns [[]] if [F.to_data] returns [Nothing] on provided state.
      *)
  val collect_dependent_and_pass_the_baton_by_hash :
       dsu:Processed_skipping.Dsu.t
    -> transition_states:Transition_state.t State_hash.Table.t
    -> State_hash.t
    -> Transition_state.t list

  (** Update status to [Substate.Processing (Substate.Done _)]. 
      
      If [reuse_ctx] is [true], if there is an [Substate.In_progress] context and
      there is an unprocessed ancestor covered by this active progress, action won't
      be interrupted and it will be assigned to the first unprocessed ancestor.

      If [baton] is set to [true] in the transition being updated the baton will be
      passed to the next transition with [Substate.Processing (Substate.In_progress _)]
      and transitions in between will get restarted.  *)
  val update_to_processing_done :
       transition_states:Transition_state.t State_hash.Table.t
    -> state_hash:State_hash.t
    -> dsu:Processed_skipping.Dsu.t
    -> ?reuse_ctx:bool
    -> F.proceessing_result
    -> Transition_state.t list option

  (** Update status to [Substate.Failed].

      If [baton] is set to [true] in the transition being updated the baton
      will be passed to the next transition with
      [Substate.Processing (Substate.In_progress _)] and transitions in between will
      get restarted.  *)
  val update_to_failed :
       transition_states:Transition_state.t State_hash.Table.t
    -> state_hash:State_hash.t
    -> dsu:Processed_skipping.Dsu.t
    -> Error.t
    -> Transition_state.t list option
end
