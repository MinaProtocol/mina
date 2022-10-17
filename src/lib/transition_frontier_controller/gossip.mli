open Mina_base

(** Determine if the header received via gossip is relevant
    (to be added to catchup state), irrelevant (to be ignored)
    or contains some useful data to be preserved 
    (in case transition is already in catchup state).
  
    Depending on relevance status, metrics are updated for the peer who sent the transition.
*)
val verify_header_is_relevant :
     context:(module Context.CONTEXT)
  -> sender:Network_peer.Envelope.Sender.t
  -> transition_states:Transition_state.t State_hash.Table.t
  -> Mina_block.Header.with_hash
  -> [ `Irrelevant | `Preserve_gossip_data | `Relevant ]

(** [preserve_relevant_gossip] takes data of a recently received gossip related to a
    transition already present in the catchup state. It preserves useful data of gossip
    in the catchup state.
    
    Function returns a pair of a new transition state and a hint of further action to be
    performed in case the gossiped data triggering a change of state.
    *)
val preserve_relevant_gossip :
     ?body:Mina_block.Body.t
  -> ?vc:Mina_net2.Validation_callback.t
  -> context:(module Context.CONTEXT)
  -> state_hash:State_hash.t
  -> ?gossip_type:[ `Block | `Header ]
  -> ?gossip_header:Mina_block.initial_valid_header
  -> Transition_state.t
  -> Transition_state.t
     * [ `Nop
       | `Mark_verifying_blockchain_proof_processed of
         Mina_block.initial_valid_header
       | `Promote_and_interrupt of unit Async.Ivar.t
       | `Start_processing_verifying_complete_works of
         Mina_block.initial_valid_block ]
