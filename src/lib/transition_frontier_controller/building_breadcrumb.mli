open Mina_base

val promote_to :
     mark_processed_and_promote:(State_hash.t list -> unit)
  -> context:(module Context.CONTEXT)
  -> transition_states:Transition_state.t State_hash.Table.t
  -> block:Mina_block.Validation.initial_valid_with_block
  -> substate:'a Substate.common_substate
  -> block_vc:Mina_net2.Validation_callback.t option
  -> Transition_state.t
