(** A provider that can compute snark work. Captures proof_level,
    signature_kind, proof_cache_db, logger, and the proving module
    at creation time. *)
type provider

val create_direct :
     proof_level:Genesis_constants.Proof_level.t
  -> proof_cache_db:Proof_cache_tag.cache_db
  -> signature_kind:Mina_signature_kind.t
  -> logger:Logger.t
  -> (module Transaction_snark.S)
  -> provider

(** Create a parallel provider that dispatches work items to N worker
    processes via Rpc_parallel. Each worker has its own Transaction_snark.Make
    instance with isolated snarky state, enabling real parallelism. Workers
    are spawned during creation and persist for the provider's lifetime. *)
val create_parallel :
     num_workers:int
  -> proof_level:Genesis_constants.Proof_level.t
  -> proof_cache_db:Proof_cache_tag.cache_db
  -> signature_kind:Mina_signature_kind.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> logger:Logger.t
  -> provider Async.Deferred.t

val compute :
     provider
  -> fee:Currency.Fee.t
  -> prover_key:Signature_lib.Public_key.Compressed.t
  -> ( Transaction_witness.t
     , Ledger_proof.Cached.t )
     Snark_work_lib.Work.Single.Spec.t
     One_or_two.t
     list
  -> (   Transaction_snark_work.Statement.t
      -> Transaction_snark_work.Checked.t option )
     Async.Deferred.Or_error.t
