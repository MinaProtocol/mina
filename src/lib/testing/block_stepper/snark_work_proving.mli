(** Core proving function for non-zkapp transactions.
    Used by the direct in-process provider's prove_base implementation. *)

val prove_non_zkapp :
     sok_digest:Mina_base.Sok_message.Digest.t
  -> (module Transaction_snark.S)
  -> Mina_state.Snarked_ledger_state.With_sok.t
  -> Transaction_witness.Stable.V2.t
  -> Mina_transaction.Transaction.Valid.t
  -> Ledger_proof.t Async.Deferred.Or_error.t
