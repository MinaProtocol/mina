open Mina_base

(** Promote a transition that is in [Verifying_blockchain_proof] state with
    [Processed] status to [Downloading_body] state.
*)
val promote_to :
     context:(module Context.CONTEXT)
  -> mark_processed_and_promote:(State_hash.t list -> unit)
  -> transition_states:Transition_state.t State_hash.Table.t
  -> substate:
       Mina_block.Validation.initial_valid_with_header Substate.common_substate
  -> gossip_data:Transition_state.transition_gossip_t
  -> body_opt:Mina_block.Body.t option
  -> Transition_state.t
