open Bit_catchup_state

(** Promote a transition that is in [Building_breadcrumb] state with
    [Processed] status to [Waiting_to_be_added_to_frontier] state.
*)
val promote_to :
     context:(module Context.CONTEXT)
  -> block_vc:Mina_net2.Validation_callback.t option
  -> aux:Transition_state.aux_data
  -> substate:Frontier_base.Breadcrumb.t Substate.t
  -> Transition_state.t

(** [handle_produced_transition] adds locally produced block to the catchup state *)
val handle_produced_transition :
     context:(module Context.CONTEXT)
  -> state:Bit_catchup_state.t
  -> Frontier_base.Breadcrumb.t
  -> Transition_state.t option
