open Core_kernel
open Snark_work_lib

type t

val create :
     job:(Spec.Single.t, Id.Single.t) With_job_meta.t
  -> unscheduled_segments:Spec.Sub_zkapp.t Base.Queue.t
  -> pending_mergeable_proofs:Ledger_proof.Cached.t Deque.t
  -> merge_remaining:int
  -> t

val generate_merge : t:t -> unit -> Spec.Sub_zkapp.t option

val generate_segment : t:t -> unit -> Spec.Sub_zkapp.t option

val generate_job_spec : t -> Spec.Sub_zkapp.t option

val submit_proof :
     t
  -> proof:Ledger_proof.Cached.t
  -> elapsed:Core_kernel_private.Span_float.t
  -> unit
