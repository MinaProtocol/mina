open Mina_base

(** [handle_collected_transition] adds a transition that was collected during bootstrap
    to the catchup state. *)
val handle_collected_transition :
     context:(module Context.CONTEXT)
  -> mark_processed_and_promote:(State_hash.t list -> unit)
  -> state:Context.catchup_state
  -> Bootstrap_controller.Transition_cache.initial_valid_block_or_header
     Network_peer.Envelope.Incoming.t
     * Mina_net2.Validation_callback.t option
  -> unit

(** [handle_network_transition] adds a transition that was received through gossip
    to the catchup state. *)
val handle_network_transition :
     context:(module Context.CONTEXT)
  -> mark_processed_and_promote:(State_hash.t list -> unit)
  -> state:Context.catchup_state
  -> [< `Block of
        Mina_block.Validation.initial_valid_with_block
        Network_peer.Envelope.Incoming.t
     | `Header of
       Mina_block.Validation.initial_valid_with_header
       Network_peer.Envelope.Incoming.t ]
     * [< `Valid_cb of Mina_net2.Validation_callback.t option ]
  -> unit
