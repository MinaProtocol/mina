open Core_kernel
open Snark_work_lib

type t =
  { job : (Spec.Single.t, Id.Single.t) With_job_meta.t
        (* the original work being splitted, should be identical to Work_selector.work *)
  ; unscheduled_segments : Spec.Sub_zkapp.t Queue.t
  ; pending_mergable_proofs : Ledger_proof.Cached.t Deque.t
        (* we may need to insert proofs to merge back to the queue, hence a Deque *)
  ; mutable elapsed : Time.Stable.Span.V1.t
  ; mutable merge_remaining : int
  }

val generate_merge : t:t -> unit -> Spec.Sub_zkapp.t option

val generate_segment : t:t -> unit -> Spec.Sub_zkapp.t option

val generate_job_spec : t -> Spec.Sub_zkapp.t option

val submit_proof :
     t
  -> proof:Ledger_proof.Cached.t
  -> elapsed:Core_kernel_private.Span_float.t
  -> unit
