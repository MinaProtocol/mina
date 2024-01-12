open Mina_base
open Core_kernel
open Bit_catchup_state

include module type of Verifying_generic_types

module Make : functor (F : F) -> sig
  (** Collect transitions that are either in [Substate.Processing Substate.Dependent]
      or in [Substate.Failed] statuses and set [baton] to [true] for the next
      ancestor in [Substate.Processing (Substate.In_progress _)] status.
      
      Traversal starts with a transition represented by its state and the state is also
      included into result (or has [baton] set to [true]) if it satisfies the conditions.
        
      Function does nothing and returns [[]] if [F.to_data] returns [Nothing] on provided state.
      *)
  val collect_dependent_and_pass_the_baton :
       logger:Logger.t
    -> transition_states:Transition_states.t
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
       logger:Logger.t
    -> dsu:Processed_skipping.Dsu.t
    -> transition_states:Transition_states.t
    -> State_hash.t
    -> Transition_state.t list

  (** Pass processing context to the next unprocessed state.
      If the next unprocessed state is in [Substate.Processing (Substate.In_progress )]
      status or if it's below context's [downto_] field, context is canceled
      and no transition gets updated.

      If [baton] is set to [true], next's baton will also be set to [true]
      (and be left as it is otherwise).

      Returns true if the context was succesfully passed to some ancestor
  *)
  val pass_ctx_to_next_unprocessed :
       logger:Logger.t
    -> transition_states:Transition_states.t
    -> dsu:Processed_skipping.Dsu.t
    -> baton:bool
    -> State_hash.t
    -> F.processing_result Substate_types.processing_context option
    -> bool

  (** Given [res] and [state_hash], update corresponding transition to status
      [Processing (Done res)] (if it exists in transition states, is of the
      expected state and has status either [Processing] or [Failed]).

      Baton of the state is set to [false].
      
      Returns a tuple of state, previous baton value and optional processing
      context (if status was [Processing ctx]) or [None] if
      [state_hash] didn't meet conditions above. *)
  val update_to_processing_done :
       logger:Logger.t
    -> transition_states:Transition_states.t
    -> state_hash:State_hash.t
    -> F.processing_result
    -> ( Transition_state.t
       * bool
       * F.processing_result Substate_types.processing_context option )
       option

  (** Update status to [Substate.Failed].

      If [baton] is set to [true] in the transition being updated the baton
      will be passed to the next transition with
      [Substate.Processing (Substate.In_progress _)] and transitions in between will
      get restarted.  *)
  val update_to_failed :
       logger:Logger.t
    -> transition_states:Transition_states.t
    -> state_hash:State_hash.t
    -> dsu:Processed_skipping.Dsu.t
    -> Error.t
    -> Transition_state.t list option

  val start :
       context:(module Context.CONTEXT)
    -> actions:Misc.actions Async_kernel.Deferred.t
    -> transition_states:Transition_states.t
    -> Transition_state.t list
    -> unit

  val launch_in_progress :
       context:(module Context.CONTEXT)
    -> actions:Misc.actions Async_kernel.Deferred.t
    -> transition_states:Transition_states.t
    -> Transition_state.t Mina_stdlib.Nonempty_list.t
    -> F.processing_result Substate.processing_context
end
