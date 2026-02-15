(** An Rpc_parallel worker process that initializes its own
    Transaction_snark.Make instance and proves individual work specs.
    Each worker process has complete isolation of snarky's mutable state,
    enabling real parallelism across multiple worker processes. *)

type t

val create :
     logger:Logger.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> signature_kind:Mina_signature_kind.t
  -> t Async.Deferred.t

(** Send a single work spec to the worker process for proving.
    The spec must use Stable types (no proof caching). *)
val prove_single :
     t
  -> Snark_work_lib.Spec.Single.Stable.Latest.t
  -> Ledger_proof.t Async.Deferred.Or_error.t

val close : t -> unit Async.Deferred.t
