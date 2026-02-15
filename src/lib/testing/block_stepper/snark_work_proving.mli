(** Core proving functions that work with Stable types (no proof caching).
    These are shared between the direct in-process provider and the
    Rpc_parallel worker processes. *)

val prove_from_stable_spec :
     proof_cache_db:Proof_cache_tag.cache_db
  -> signature_kind:Mina_signature_kind.t
  -> sok_digest:Mina_base.Sok_message.Digest.t
  -> logger:Logger.t
  -> (module Transaction_snark.S)
  -> Snark_work_lib.Spec.Single.Stable.Latest.t
  -> Ledger_proof.t Async.Deferred.Or_error.t

val prove_dummy_from_stable_spec :
     Snark_work_lib.Spec.Single.Stable.Latest.t
  -> Ledger_proof.t Async.Deferred.Or_error.t
