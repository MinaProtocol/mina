(* NOTE: Assumption: order of merging segment proofs is irrelvant to the
   correctness of the final proof. *)

open Core_kernel
open Snark_work_lib

type t =
  { job : (Spec.Single.t, Id.Single.t) With_job_meta.t
        (** the original work being split, contains `Work_selector.work` with
            some metadata. *)
  ; unscheduled_segments : Spec.Sub_zkapp.Stable.Latest.t Queue.t
  ; pending_mergeable_proofs : Ledger_proof.t Deque.t
        (* we may need to insert proofs to merge back to the queue, hence a Deque
         *)
  ; mutable elapsed : Time.Stable.Span.V1.t
        (** The total work time for all SNARK workers combined to prove this
            specific zkapp command. I.e. the time it would take a single SNARK
            worker to generate the final proof of this command. *)
  ; mutable proofs_in_flight : int
        (** The number of proofs we need to wait for before being sure we could
            continue with the only proof contained in [pending_mergeable_proofs]
            as the final proof, provided [unscheduled_segments] being empty. *)
  }

let create_and_yield_segment ~job
    ~(unscheduled_segments :
       Spec.Sub_zkapp.Stable.Latest.t Mina_stdlib.Nonempty_list.t ) =
  let first_segment, unscheduled_segments =
    Mina_stdlib.Nonempty_list.uncons unscheduled_segments
  in
  ( { job
    ; unscheduled_segments = Queue.of_list unscheduled_segments
    ; pending_mergeable_proofs = Deque.create ()
    ; elapsed = Time.Span.zero
    ; proofs_in_flight = 1
    }
  , first_segment )

let zkapp_job t = t.job

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

(** [next_merge t] attempts dequeuing 2 proofs from [t.pending_mergeable_proofs]
    and generate a sub-zkapp level spec merging them together. *)
let next_merge (t : t) =
  let open Option.Let_syntax in
  let%map proof1, proof2 = try_take2 t.pending_mergeable_proofs in
  t.proofs_in_flight <- t.proofs_in_flight + 1 ;
  Spec.Sub_zkapp.Stable.Latest.Merge { proof1; proof2 }

(** [next_segment t] dequeus a segment from [t.unscheduled_segments] and generate a
   sub-zkapp level spec proving that segment. *)
let next_segment (t : t) =
  let open Option.Let_syntax in
  let%map segment = Queue.dequeue t.unscheduled_segments in
  t.proofs_in_flight <- t.proofs_in_flight + 1 ;
  segment

let next_subzkapp_job_spec (t : t) : Spec.Sub_zkapp.Stable.Latest.t option =
  match next_merge t with Some _ as ret -> ret | None -> next_segment t

let submit_proof (t : t) ~(proof : Ledger_proof.t)
    ~(elapsed : Time.Stable.Span.V1.t) =
  Deque.enqueue_back t.pending_mergeable_proofs proof ;
  t.proofs_in_flight <- t.proofs_in_flight - 1 ;
  t.elapsed <- Time.Span.(t.elapsed + elapsed)

let try_finalize (t : t) =
  if
    t.proofs_in_flight = 0
    && Queue.is_empty t.unscheduled_segments
    && Deque.length t.pending_mergeable_proofs = 1
  then Some (t.job, Deque.dequeue_back_exn t.pending_mergeable_proofs, t.elapsed)
  else None
