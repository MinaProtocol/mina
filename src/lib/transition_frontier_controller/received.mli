(** [handle_collected_transition] adds a transition that was collected during bootstrap
    to the catchup state. *)
val handle_collected_transition :
     context:(module Context.CONTEXT)
  -> actions:Misc.actions
  -> state:Bit_catchup_state.t
  -> Transition_frontier.Gossip.element
  -> [ `No_body_preserved
     | `Preserved_body of Consensus.Body_reference.t * Mina_block.Body.t ]

(** [handle_network_transition] adds a transition that was received through gossip
    to the catchup state. *)
val handle_network_transition :
     context:(module Context.CONTEXT)
  -> actions:Misc.actions
  -> state:Bit_catchup_state.t
  -> Transition_frontier.Gossip.element
  -> [ `No_body_preserved
     | `Preserved_body of Consensus.Body_reference.t * Mina_block.Body.t ]

val handle_downloaded_body :
     context:(module Context.CONTEXT)
  -> actions:Misc.actions
  -> known_body_refs:Bit_catchup_state.Known_body_refs.t
  -> transition_states:Bit_catchup_state.Transition_states.t
  -> Consensus.Body_reference.t
  -> unit

val pre_validate_and_add_retrieved :
     context:(module Context.CONTEXT)
  -> actions:Misc.actions
  -> ?sender:Network_peer.Peer.t
  -> state:Bit_catchup_state.t
  -> ?body:Mina_block.Body.t
  -> Mina_block.Header.with_hash
  -> unit Core_kernel.Or_error.t
