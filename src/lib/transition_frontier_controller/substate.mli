open Core_kernel
open Mina_base

include module type of Substate_types

(** View the common substate.
    
    Viewer [~f] is applied to the common substate
    and its result is returned by the function.
  *)
val view :
     state_functions:(module State_functions with type state_t = 'state_t)
  -> f:'a viewer
  -> 'state_t
  -> 'a option

(** [collect_states top_state] collects transitions from the top state (inclusive) down the ancestry chain 
  while:
  
    1. Condition [predicate] is held
    and
    2. Have same state level as [top_state]

    Returned list of states is in the child-first order.
*)
val collect_states :
     predicate:([ `Take of bool ] * [ `Continue of bool ]) viewer
  -> state_functions:(module State_functions with type state_t = 'state_t)
  -> transition_states:'state_t State_hash.Table.t
  -> 'state_t
  -> 'state_t list

(** [collect_dependent_ancestry top_state] collects transitions from the top state (inclusive) down the ancestry chain 
  while collected states are:
  
    1. In [Waiting_for_parent], [Failed] or [Processing Dependent] substate
    and
    2. Have same state level as [top_state]

    States with [Processed] status are skipped through.
    Returned list of states is in the child-first order.
*)
val collect_dependent_ancestry :
     state_functions:(module State_functions with type state_t = 'a)
  -> transition_states:'a State_hash.Table.t
  -> 'a
  -> 'a list

(** [mark_processed processed] marks a list of state hashes as Processed.

  It returns a list of state hashes to be promoted to higher state.
   
  Pre-conditions:
   1. Order of [processed] respects parent-child relationship and parent always comes first
   2. Respective substates for states from [processed] are in [Processing (Done _)] status

  Post-condition: list returned respects parent-child relationship and parent always comes first *)
val mark_processed :
     logger:Logger.t
  -> state_functions:(module State_functions with type state_t = 'state_t)
  -> transition_states:'state_t State_hash.Table.t
  -> State_hash.t list
  -> State_hash.t list

val update_children_on_promotion :
     state_functions:(module State_functions with type state_t = 'state_t)
  -> transition_states:'state_t State_hash.Table.t
  -> parent_hash:State_hash.t
  -> state_hash:State_hash.t
  -> 'state_t option
  -> unit

(** [view_processing] functions takes state and returns [`Done] if the processing is finished,
    [`In_progress timeout] is the processing continues and [None] if the processing is dependent
      or status is different from [Processing].  *)
val view_processing :
     state_functions:(module State_functions with type state_t = 'a)
  -> 'a
  -> [> `Done | `In_progress of Time.t ] option

module For_tests : sig
  (** [collect_failed_ancestry top_state] collects transitions from the top state (inclusive)
  down the ancestry chain that are:
  
    1. In [Failed] substate
    and
    2. Have same state level as [top_state]

    Returned list of states is in the child-first order.
*)
  val collect_failed_ancestry :
       state_functions:(module State_functions with type state_t = 'a)
    -> transition_states:'a State_hash.Table.t
    -> 'a
    -> 'a list
end
