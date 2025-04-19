open Core_kernel
module Shared = Shared
module Partitioned_work = Snark_work_lib.Partitioned
module Zkapp_command_job_with_status =
  With_job_status.Make (Partitioned_work.Zkapp_command_job)

(* NOTE: this module is where the real optimization happen. One assumption we
   have is the order of merging is irrelvant to the correctness of the final
   proof. Hence we're only using a counter `merge_remaining` to track have we
   reach the final proof
*)
module Pending_Zkapp_command = struct
  type t =
    { spec : Work_types.Compact.Single.Spec.t
          (* the original work being splitted, should be identical to Work_selector.work *)
    ; unscheduled_segments : Partitioned_work.Zkapp_command_job.Spec.t Queue.t
          (* we may need to insert proofs to merge back to the queue, hence a Deque *)
    ; pending_mergable_proofs : Ledger_proof.Cached.t Deque.t
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
    Partitioned_work.Zkapp_command_job.Spec.Merge { proof1; proof2 }

  let generate_segment ~(t : t) () =
    let open Option.Let_syntax in
    let%map segment = Queue.dequeue t.unscheduled_segments in
    segment

  let generate_job_spec (t : t) :
      Partitioned_work.Zkapp_command_job.Spec.t option =
    List.find_map ~f:(fun f -> f ()) [ generate_merge ~t; generate_segment ~t ]

  let submit_proof (t : t) ~(p : Ledger_proof.Cached.t)
      ~(elapsed : Time.Stable.Span.V1.t) =
    Deque.enqueue_back t.pending_mergable_proofs p ;
    t.merge_remaining <- t.merge_remaining - 1 ;
    t.elapsed <- Time.Span.(t.elapsed + elapsed)
end

module Zkapp_command_job_pool =
  Job_pool.Make (Partitioned_work.Pairing) (Pending_Zkapp_command)
module Sent_job_pool =
  Job_pool.Make
    (Partitioned_work.Zkapp_command_job.UUID)
    (Zkapp_command_job_with_status)

type t =
  { logger : Logger.t
  ; transaction_snark : (module Transaction_snark.S)
        (* WARN: we're mixing UUID for `pairing_pool` and `zkapp_command_jobs.
           Should be fine *)
  ; uuid_generator : Uuid_generator.t (* NOTE: Fields for pooling *)
  ; pairing_pool : (Partitioned_work.Pairing.UUID.t, Single_work.t) Hashtbl.t
        (* if one single work from underlying Work_selector is completed but
           not the other. throw it here. *)
  ; zkapp_command_jobs : Zkapp_command_job_pool.t
        (* NOTE: Fields for reissue pooling*)
  ; reassignment_timeout : Time.Span.t
  ; jobs_sent_by_partitioner : Sent_job_pool.t
        (* we only track tasks created by a Work_partitioner here. For reissue
           of regular jobs, we still turn to the underlying Work_selector *)
        (* WARN: we're assuming everything in this queue is sorted in time from old to new.
           So queue head is the oldest task.
        *)
  ; mutable first_in_pair : Work_types.Compact.Single.Spec.t option
        (* When receving a `Two works from the underlying Work_selector, store one of them here,
           so we could issue them to another worker.
        *)
  }

let create ~(reassignment_timeout : Time.Span.t) ~(logger : Logger.t) : t =
  let module M = Transaction_snark.Make (struct
    let constraint_constants = Genesis_constants.Compiled.constraint_constants

    let proof_level = Genesis_constants.Compiled.proof_level
  end) in
  { logger
  ; transaction_snark = (module M)
  ; uuid_generator = Uuid_generator.create ()
  ; pairing_pool = Hashtbl.create (module Partitioned_work.Pairing.UUID)
  ; zkapp_command_jobs = Zkapp_command_job_pool.create ()
  ; reassignment_timeout
  ; jobs_sent_by_partitioner = Sent_job_pool.create ()
  ; first_in_pair = None
  }
