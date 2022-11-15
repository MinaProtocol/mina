open Mina_base

include module type of Gossip_types

(** Determine if the header received via gossip is relevant
    (to be added to catchup state), irrelevant (to be ignored)
    or contains some useful data to be preserved 
    (in case transition is already in catchup state).
  
    Depending on relevance status, metrics are updated for the peer who sent the transition.
*)
val verify_header_is_relevant :
     context:(module Context.CONTEXT)
  -> sender:Network_peer.Envelope.Sender.t
  -> transition_states:Transition_states.t
  -> Mina_block.Header.with_hash
  -> [ `Irrelevant | `Preserve_gossip_data | `Relevant ]

(** Preserve body in the transition's state.
    
    Function is called when a gossip with a body is received or
    when a transition is retrieved through ancestry retrieval with a body
    (i.e. via using old RPCs).

    In case of [Transition_state.Downloading_body] state in [Substate.Failed] or
    [Substate.Processing (Substate.In_progress _)] statuses, status is changed
    to [Substate.Processing (Substate.Done _)] and [`Mark_downloading_body_processed]
    hint is returned. Returned hint is [`Nop] otherwise.
*)
val preserve_body :
     body:Mina_block.Body.t
  -> Transition_state.t
  -> Transition_state.t
     * [> `Nop
       | `Mark_downloading_body_processed of unit Async_kernel.Ivar.t option ]

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
  -> gossip_type:[ `Block | `Header ]
  -> gossip_header:Mina_block.initial_valid_header
  -> Transition_state.t
  -> Transition_state.t
     * [ `Nop
       | `Mark_verifying_blockchain_proof_processed of
         Mina_block.initial_valid_header
       | `Mark_downloading_body_processed of unit Async_kernel.Ivar.t option
       | `Start_processing_verifying_complete_works of State_hash.t ]
