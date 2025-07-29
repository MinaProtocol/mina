open Core_kernel
open Snark_work_lib

(** [t] is a pool for zkapp segments and mergeable proofs corresponding to a
    single zkapp transaction. *)
type t

(** [create_and_yield_segment ~job ~unscheduled_segments] creates a pending
    zkapp command instance, and immediately generate a segment subzkapp spec. *)
val create_and_yield_segment :
     job:(Spec.Single.t, Id.Single.t) With_job_meta.t
  -> unscheduled_segments:
       (Spec.Sub_zkapp.Stable.V1.t * Id.Range.Stable.V1.t)
       Mina_stdlib.Nonempty_list.Stable.V1.t
  -> t * (Spec.Sub_zkapp.Stable.V1.t * Id.Range.Stable.V1.t)

val zkapp_job : t -> (Spec.Single.t, Id.Single.t) With_job_meta.t

(** [next_subzkapp_job_spec t] extracts another job spec from t, mutating the internal
    state of [t]. Once any job spec returned is completed, it's expected to be
    submitted back to [t] with [submit_proof] *)
val next_subzkapp_job_spec :
  t -> (Spec.Sub_zkapp.Stable.V1.t * Id.Range.Stable.V1.t) option

(* [submit_proof t ~proof ~elapsed ~range] submit a proof corresponding to
   a range of segments(both inclusive). This throws error if either the range is
   invalid or some corresponded segment proof is already present in [t] *)
val submit_proof :
     proof:Ledger_proof.t
  -> elapsed:Core_kernel_private.Span_float.t
  -> range:Id.Range.Stable.V1.t
  -> t
  -> (unit, Error.t) result

(** [try_finalize t] attempts to unwrap completed proof, metric and spec from
    [t] if the proof for entire zkapp transaction is completed *)
val try_finalize :
     t
  -> ( (Spec.Single.t, Id.Single.t) With_job_meta.t
     * Ledger_proof.t
     * Time.Stable.Span.V1.t )
     option
