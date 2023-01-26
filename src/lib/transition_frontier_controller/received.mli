open Mina_base

(** [handle_collected_transition] adds a transition that was collected during bootstrap
    to the catchup state. *)
val handle_collected_transition :
     context:(module Context.CONTEXT)
  -> actions:Misc.actions
  -> state:Bit_catchup_state.t
  -> Transition_frontier.Gossip.element
  -> [ `No_body_preserved | `Preserved_body of Mina_block.Body.t ]

(** [handle_network_transition] adds a transition that was received through gossip
    to the catchup state. *)
val handle_network_transition :
     context:(module Context.CONTEXT)
  -> actions:Misc.actions
  -> state:Bit_catchup_state.t
  -> Transition_frontier.Gossip.element
  -> [ `No_body_preserved | `Preserved_body of Mina_block.Body.t ]

val handle_downloaded_body :
     context:(module Context.CONTEXT)
  -> actions:Misc.actions
  -> body_reference_to_state_hash:State_hash.t Context.Body_ref_table.t
  -> transition_states:Bit_catchup_state.Transition_states.t
  -> Consensus.Body_reference.t
  -> ( State_hash.t
     * [ `No_body_preserved | `Preserved_body of Mina_block.Body.t ] )
     option
