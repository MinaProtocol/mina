open Mina_base

(** Promote a transition that is in [Verifying_complete_works] state with
    [Processed] status to [Building_breadcrumb] state.
*)
val promote_to :
     mark_processed_and_promote:(State_hash.t list -> unit)
  -> context:(module Context.CONTEXT)
  -> transition_states:Transition_states.t
  -> block:Mina_block.Validation.initial_valid_with_block
  -> substate:unit Substate.t
  -> block_vc:Mina_net2.Validation_callback.t option
  -> aux:Transition_state.aux_data
  -> Transition_state.t
