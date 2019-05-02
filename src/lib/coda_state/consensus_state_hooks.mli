include
  Consensus.Hooks.State_hooks_intf
  with type blockchain_state := Blockchain_state.Value.t
   and type protocol_state := Protocol_state.Value.t
   and type protocol_state_var := Protocol_state.var
   and type snark_transition_var := Snark_transition.var
