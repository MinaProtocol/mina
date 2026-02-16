(** Shared proving types and factory used by both the direct (in-process)
    and parallel (worker-process) snark work providers. *)

type prove_base_input =
  { statement : Mina_state.Snarked_ledger_state.With_sok.t
  ; witness : Transaction_witness.Stable.V2.t
  }

type prove_zkapp_segment_input =
  { statement : Mina_state.Snarked_ledger_state.With_sok.t
  ; witness : Transaction_snark.Zkapp_command_segment.Witness.t
  ; spec : Transaction_snark.Zkapp_command_segment.Basic.t
  }

type prove_merge_input =
  { proof1 : Ledger_proof.t
  ; proof2 : Ledger_proof.t
  ; sok_digest : Mina_base.Sok_message.Digest.t
  }

type t =
  { prove_base : prove_base_input -> Ledger_proof.t Async.Deferred.Or_error.t
  ; prove_zkapp_segment :
      prove_zkapp_segment_input -> Ledger_proof.t Async.Deferred.Or_error.t
  ; prove_merge : prove_merge_input -> Ledger_proof.t Async.Deferred.Or_error.t
  ; how : Async_kernel.Monad_sequence.how
  }

val prove_base :
  t -> prove_base_input -> Ledger_proof.t Async.Deferred.Or_error.t

val prove_zkapp_segment :
  t -> prove_zkapp_segment_input -> Ledger_proof.t Async.Deferred.Or_error.t

val prove_merge :
  t -> prove_merge_input -> Ledger_proof.t Async.Deferred.Or_error.t

val how : t -> Async_kernel.Monad_sequence.how

(** Create a sequential prover from a [Transaction_snark.S] module.
    The returned [t] has [how = `Sequential] and implements all three
    proving functions using the given module. *)
val make :
  signature_kind:Mina_signature_kind.t -> (module Transaction_snark.S) -> t
