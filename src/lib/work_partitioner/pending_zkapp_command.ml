(* NOTE: this module is where the real optimization happen. One assumption we
   have is the order of merging is irrelvant to the correctness of the final
   proof. Hence we're only using a counter `merge_remaining` to track have we
   reach the final proof
*)

open Core_kernel
open Snark_work_lib

type t =
  { job : (Spec.Single.t, Id.Single.t) With_job_meta.t
        (** the original work being splitted, should be identical to
            Work_selector.work *)
  ; unscheduled_segments : Spec.Sub_zkapp.Stable.Latest.t Queue.t
  ; pending_mergeable_proofs : Ledger_proof.t Deque.t
        (** we may need to insert proofs to merge back to the queue, hence a
            Deque *)
  ; mutable elapsed : Time.Stable.Span.V1.t
        (** The total work time for all SNARK workers combined to prove this
            specific zkapp command. Or, the time it would take a single SNARK
            worker to generate the final proof of this command. *)
  ; mutable merge_remaining : int
        (** The number of merges we need to perform before getting the final
            proof. This is needed because in `pending_mergeable_proofs` we
            don't know the number of segments each proof correspond to. *)
  }

let create ~job ~unscheduled_segments ~pending_mergeable_proofs ~merge_remaining
    =
  { job
  ; unscheduled_segments
  ; pending_mergeable_proofs
  ; elapsed = Time.Span.zero
  ; merge_remaining
  }

(* This function attempts dequeuing 2 proofs from `pending_mergeable_proofs` and
   generate a sub-zkapp level spec merging them together. *)
let next_merge (t : t) =
  let try_take2 (q : 'a Deque.t) : ('a * 'a) option =
    match Deque.dequeue_front q with
    | None ->
        None
    | Some fst -> (
        match Deque.dequeue_front q with
        | Some snd ->
            Some (fst, snd)
        | None ->
            Deque.enqueue_front q fst ; None )
  in
  let open Option.Let_syntax in
  let%map proof1, proof2 = try_take2 t.pending_mergeable_proofs in
  Spec.Sub_zkapp.Stable.Latest.Merge { proof1; proof2 }

(* This function dequeus a segment from `unscheduled_segments and generate a
   sub-zkapp level spec proving that segment. *)
let next_segment (t : t) =
  let open Option.Let_syntax in
  let%map segment = Queue.dequeue t.unscheduled_segments in
  segment

let generate_job_spec (t : t) : Spec.Sub_zkapp.Stable.Latest.t option =
  match next_merge t with Some _ as ret -> ret | None -> next_segment t

let submit_proof (t : t) ~(proof : Ledger_proof.t)
    ~(elapsed : Time.Stable.Span.V1.t) =
  Deque.enqueue_back t.pending_mergeable_proofs proof ;
  t.merge_remaining <- t.merge_remaining - 1 ;
  t.elapsed <- Time.Span.(t.elapsed + elapsed)
