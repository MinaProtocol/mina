open Mina_base
open Mina_state

module type Keys_S = sig
  module T : Transaction_snark.S

  module B : Blockchain_snark.Blockchain_snark_state.S
end

module Keys (Params : sig
  val signature_kind : Mina_signature_kind.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val proof_level : Genesis_constants.Proof_level.t
end) : Keys_S

val extend_blockchain :
     (module Blockchain_snark.Blockchain_snark_state.S)
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> Blockchain_snark.Blockchain.t
  -> Protocol_state.Value.t
  -> Snark_transition.value
  -> Ledger_proof.t option
  -> Consensus.Data.Prover_state.t
  -> Pending_coinbase_witness.t
  -> Blockchain_snark.Blockchain.t Async.Deferred.Or_error.t

val build_breadcrumb :
     transactions:User_command.Valid.t Core.Sequence.t
  -> context:(module Mina_block.Validation.CONTEXT)
  -> precomputed_values:Precomputed_values.t
  -> signature_kind:Mina_signature_kind.t
  -> proof_cache_db:Proof_cache_tag.cache_db
  -> protocol_states:Protocol_state.value State_hash.Map.t
  -> (module Keys_S)
  -> Consensus.Data.Slot_won.t
     * Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
  -> Frontier_base.Breadcrumb.t
  -> Frontier_base.Breadcrumb.t Async.Deferred.t
