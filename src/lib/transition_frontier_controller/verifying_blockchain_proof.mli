open Mina_base

val promote_to :
     context:(module Context.CONTEXT)
  -> mark_processed_and_promote:(State_hash.t list -> unit)
  -> header:Gossip_types.received_header
  -> transition_states:Transition_state.t State_hash.Table.t
  -> substate:unit Substate.t
  -> gossip_data:Gossip_types.transition_gossip_t
  -> body_opt:Staged_ledger_diff.Body.t option
  -> aux:Transition_state.aux_data
  -> Transition_state.t

val mark_processed :
     context:(module Context.CONTEXT)
  -> mark_processed_and_promote:(State_hash.t list -> unit)
  -> transition_states:Transition_state.t State_hash.Table.t
  -> Mina_block.Validation.initial_valid_with_header
  -> unit
