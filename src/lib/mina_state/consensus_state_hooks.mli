open Consensus
open Data

include
  Intf.State_hooks
    with type blockchain_state := Blockchain_state.Value.t
     and type protocol_state := Protocol_state.Value.t
     and type protocol_state_var := Protocol_state.var
     and type snark_transition_var := Snark_transition.var
     and type consensus_state := Consensus_state.Value.t
     and type consensus_state_var := Consensus_state.var
     and type consensus_transition := Consensus_transition.Value.t
     and type block_data := Block_data.t
