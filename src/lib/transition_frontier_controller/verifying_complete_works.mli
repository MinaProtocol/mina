open Mina_base

(** Promote a transition that is in [Downloading_body] state with
    [Processed] status to [Verifying_complete_works] state.
*)
val promote_to :
     mark_processed_and_promote:(State_hash.t list -> unit)
  -> context:(module Context.CONTEXT)
  -> transition_states:Transition_state.t State_hash.Table.t
  -> header:Mina_block.Validation.initial_valid_with_header
  -> substate:Mina_block.Body.t Substate.t
  -> block_vc:Mina_net2.Validation_callback.t option
  -> aux:Transition_state.aux_data
  -> Transition_state.t

(** [make_independent state_hash] starts verification of complete works for
       a transition corresponding to the [block].

    This function is called when a gossip is received for a transition
    that is in [Transition_state.Verifying_complete_works] state.

    Pre-condition: transition corresponding to [state_hash] has
    [Substate.Processing Dependent] status and was just received through gossip.
   *)
val make_independent :
     context:(module Context.CONTEXT)
  -> mark_processed_and_promote:(State_hash.t list -> unit)
  -> transition_states:Transition_state.t State_hash.Table.t
  -> State_hash.t
  -> unit
