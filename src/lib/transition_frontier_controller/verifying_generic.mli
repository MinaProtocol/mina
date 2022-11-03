open Mina_base
open Core_kernel

type 'a data = { substate : 'a Substate_types.t; baton : bool }

module Make : functor
  (F : sig
     type proceessing_result

     val ignore_gossip : Transition_state.t -> Transition_state.t

     val to_data : Transition_state.t -> proceessing_result data option

     val update :
       proceessing_result data -> Transition_state.t -> Transition_state.t
   end)
  -> sig
  val collect_dependent_and_pass_the_baton :
       transition_states:Transition_state.t State_hash.Table.t
    -> dsu:Processed_skipping.Dsu.t
    -> Transition_state.t
    -> Transition_state.t list

  val collect_dependent_and_pass_the_baton_by_hash :
       dsu:Processed_skipping.Dsu.t
    -> transition_states:Transition_state.t State_hash.Table.t
    -> State_hash.t
    -> Transition_state.t list

  val update_to_processing_done :
       transition_states:Transition_state.t State_hash.Table.t
    -> state_hash:State_hash.t
    -> dsu:Processed_skipping.Dsu.t
    -> ?reuse_ctx:bool
    -> ?force_baton:bool
    -> F.proceessing_result
    -> Transition_state.t list option

  val update_to_failed :
       transition_states:Transition_state.t State_hash.Table.t
    -> state_hash:State_hash.t
    -> dsu:Processed_skipping.Dsu.t
    -> Error.t
    -> Transition_state.t list option
end
