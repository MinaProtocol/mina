(** Promote a transition that is in [Building_breadcrumb] state with
    [Processed] status to [Waiting_to_be_added_to_frontier] state.
*)
val promote_to :
     context:(module Context.CONTEXT)
  -> substate:Frontier_base.Breadcrumb.t Substate.t
  -> block_vc:Mina_net2.Validation_callback.t option
  -> aux:Transition_state.aux_data
  -> Transition_state.t
