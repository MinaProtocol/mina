open Mina_base

(** Promote a transition that is in [Received] state with
    [Processed] status to [Verifying_blockchain_proof] state.
*)
val promote_to :
     context:(module Context.CONTEXT)
  -> mark_processed_and_promote:(State_hash.t list -> unit)
  -> header:Gossip.received_header
  -> transition_states:Transition_state.t State_hash.Table.t
  -> substate:unit Substate.t
  -> gossip_data:Gossip.transition_gossip_t
  -> body_opt:Staged_ledger_diff.Body.t option
  -> aux:Transition_state.aux_data
  -> Transition_state.t

(** Mark the transition in [Verifying_blockchain_proof] processed.

   This function is called when a gossip for the transition is received.
   When gossip is received, blockchain proof is verified before any
   further processing. Hence blockchain verification for the transition
   may be skipped upon receival of a gossip.

   Blockhain proof verification is performed in batches, hence in progress
   context is not discarded but passed to the next ancestor that is in 
   [Verifying_blockchain_proof] and isn't [Processed].
*)
val make_processed :
     context:(module Context.CONTEXT)
  -> mark_processed_and_promote:(State_hash.t list -> unit)
  -> transition_states:Transition_state.t State_hash.Table.t
  -> Mina_block.Validation.initial_valid_with_header
  -> unit
