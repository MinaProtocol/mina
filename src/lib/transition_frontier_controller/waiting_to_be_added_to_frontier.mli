val promote_to :
     context:(module Context.CONTEXT)
  -> substate:Frontier_base.Breadcrumb.t Substate.t
  -> block_vc:Mina_net2.Validation_callback.t option
  -> aux:Transition_state.aux_data
  -> Transition_state.t
