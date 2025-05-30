(* NOTE: this module is where the real optimization happen. One assumption we
   have is the order of merging is irrelvant to the correctness of the final
   proof. Hence we're only using a counter `merge_remaining` to track have we
   reach the final proof
*)

open Core_kernel
module Work = Snark_work_lib

type t =
  { job : (Work.Spec.Single.t, Work.ID.Single.t) Work.With_status.t
        (* the original work being splitted, should be identical to Work_selector.work *)
  ; unscheduled_segments : Work.Spec.Sub_zkapp.Stable.Latest.t Queue.t
  ; pending_mergable_proofs : Ledger_proof.t Deque.t
        (* we may need to insert proofs to merge back to the queue, hence a Deque *)
  ; mutable elapsed : Time.Stable.Span.V1.t
  ; mutable merge_remaining : int
  }

let generate_merge ~(t : t) () =
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
  let%map proof1, proof2 = try_take2 t.pending_mergable_proofs in
  Work.Spec.Sub_zkapp.Stable.Latest.Merge { proof1; proof2 }

let generate_segment ~(t : t) () =
  let open Option.Let_syntax in
  let%map segment = Queue.dequeue t.unscheduled_segments in
  segment

let generate_job_spec (t : t) : Work.Spec.Sub_zkapp.Stable.Latest.t option =
  List.find_map ~f:(fun f -> f ()) [ generate_merge ~t; generate_segment ~t ]

let submit_proof (t : t) ~(proof : Ledger_proof.t)
    ~(elapsed : Time.Stable.Span.V1.t) =
  Deque.enqueue_back t.pending_mergable_proofs proof ;
  t.merge_remaining <- t.merge_remaining - 1 ;
  t.elapsed <- Time.Span.(t.elapsed + elapsed)
