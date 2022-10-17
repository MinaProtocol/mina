open Mina_base

val promote_to :
     mark_processed_and_promote:(State_hash.t list -> unit)
  -> context:(module Context.CONTEXT)
  -> transition_states:Transition_state.t State_hash.Table.t
  -> header:Mina_block.Validation.initial_valid_with_header
  -> substate:Mina_block.Body.t Substate.common_substate
  -> block_vc:Mina_net2.Validation_callback.t option
  -> aux:Transition_state.aux_data
  -> Transition_state.t

val start_processing :
     context:(module Context.CONTEXT)
  -> mark_processed_and_promote:(State_hash.t list -> unit)
  -> transition_states:Transition_state.t State_hash.Table.t
  -> Mina_block.Validation.initial_valid_with_block
  -> unit
