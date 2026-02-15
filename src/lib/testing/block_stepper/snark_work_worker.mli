(** An Rpc_parallel worker process that initializes its own
    Transaction_snark.Make instance and exposes fine-grained proving RPCs.
    Each worker process has complete isolation of snarky's mutable state,
    enabling real parallelism across multiple worker processes. *)

type t

val create :
     logger:Logger.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> signature_kind:Mina_signature_kind.t
  -> t Async.Deferred.t

(** Prove a non-zkapp transaction (Signed_command, Fee_transfer, Coinbase).
    The worker checks the signature (if signed command) and calls
    [T.of_non_zkapp_command_transaction]. *)
val prove_base :
     t
  -> Mina_state.Snarked_ledger_state.With_sok.t
  -> Transaction_witness.Stable.V2.t
  -> Ledger_proof.t Async.Deferred.Or_error.t

(** Prove a single segment of a zkapp transaction. The worker calls
    [T.of_zkapp_command_segment_exn]. *)
val prove_zkapp_segment :
     t
  -> Mina_state.Snarked_ledger_state.With_sok.t
  -> Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
  -> Transaction_snark.Zkapp_command_segment.Basic.t
  -> Ledger_proof.t Async.Deferred.Or_error.t

(** Merge two proofs. The worker calls [T.merge]. *)
val prove_merge :
     t
  -> Ledger_proof.t
  -> Ledger_proof.t
  -> Mina_base.Sok_message.Digest.t
  -> Ledger_proof.t Async.Deferred.Or_error.t

val close : t -> unit Async.Deferred.t
