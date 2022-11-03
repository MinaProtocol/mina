module Data : Dsu.Data with type t = Substate_types.transition_meta

module Dsu : module type of Dsu.Make (Mina_base.State_hash) (Data)

(** [collect_unprocessed top_state] collects unprocessed transitions from
    the top state (inclusive) down the ancestry chain while:
  
    1. [predicate] returns [(`Take _, `Continue true)]
    and
    2. Have same state level as [top_state]

    States with [Processed] status are skipped through.

    Returned list of states is in the parent-first order.

    Only states for which [predicate] returned [(`Take true, `Continue_)] are collected.
    State for which [(`Take true, `Continue false)] was returned by [predicate] will be taken.

    Complexity of this function is [O(n)] for [n] being the number of
    states returned plus the number of states for which [`Take false] was returned.
*)
val collect_unprocessed :
     ?predicate:([ `Take of bool ] * [ `Continue of bool ]) Substate_types.viewer
  -> state_functions:
       (module Substate.State_functions with type state_t = 'state_t)
  -> transition_states:'state_t Mina_base.State_hash.Table.t
  -> dsu:Dsu.t
  -> 'state_t
  -> 'state_t list

(** [next_unprocessed top_state] finds next unprocessed transition of the same state level
    from the top state (inclusive) down the ancestry chain while.

    This function has quasi-constant complexity.
*)
val next_unprocessed :
     state_functions:
       (module Substate.State_functions with type state_t = 'state_t)
  -> transition_states:'state_t Mina_base.State_hash.Table.t
  -> dsu:Dsu.t
  -> 'state_t
  -> 'state_t option

(** [collect_to_in_progress top_state] collects unprocessed transitions from
    the top state (inclusive) down the ancestry chain while:
  
    1. Transitions are not in [Substate.Processing (Substate.In_progress _)] state
    and
    2. Have same state level as [top_state]

    First encountered [Substate.Processing (Substate.In_progress _)] transition (if any)
    is also included in the result. Returned list of states is in the parent-first order.

    Complexity of this funciton is [O(n)] for [n] being the size of the returned list.
*)
val collect_to_in_progress :
     state_functions:
       (module Substate.State_functions with type state_t = 'state_t)
  -> transition_states:'state_t Mina_base.State_hash.Table.t
  -> dsu:Dsu.t
  -> 'state_t
  -> 'state_t list
