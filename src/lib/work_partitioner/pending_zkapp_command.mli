open Core_kernel
open Snark_work_lib

type t

val create :
     job:(Spec.Single.t, Id.Single.t) With_job_meta.t
  -> unscheduled_segments:Spec.Sub_zkapp.Stable.Latest.t Base.Queue.t
  -> pending_mergeable_proofs:Ledger_proof.t Deque.t
  -> t

val generate_job_spec : t -> Spec.Sub_zkapp.Stable.Latest.t option

val submit_proof :
  t -> proof:Ledger_proof.t -> elapsed:Core_kernel_private.Span_float.t -> unit
