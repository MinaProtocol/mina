open Core_kernel
module Shared = Shared
module Partitioned_work = Snark_work_lib.Partitioned
module Selector_work = Snark_work_lib.Selector
module Zkapp_command_job_with_status =
  With_job_status.Make (Partitioned_work.Zkapp_command_job)

(* NOTE: this module is where the real optimization happen. One assumption we
   have is the order of merging is irrelvant to the correctness of the final
   proof. Hence we're only using a counter `merge_remaining` to track have we
   reach the final proof
*)
module Pending_Zkapp_command = struct
  type t =
    { spec : Selector_work.Single_spec.t
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
  ; mutable first_in_pair : Selector_work.Single_spec.t option
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

(* Logics for work requesting *)
let reissue_old_task ~(partitioner : t) () :
    Partitioned_work.Single.Spec.t option =
  let job_is_old (job : Zkapp_command_job_with_status.t) : bool =
    Zkapp_command_job_with_status.is_old ~now:(Time.now ())
      ~limit:partitioner.reassignment_timeout job
  in
  match
    Sent_job_pool.take_first_ready ~pred:job_is_old
      partitioner.jobs_sent_by_partitioner
  with
  | None ->
      None
  | Some (id, job_with_status) ->
      let reissued = { job_with_status with assigned = Time.now () } in
      Sent_job_pool.replace ~id ~job:reissued
        partitioner.jobs_sent_by_partitioner ;
      Some (Sub_zkapp_command job_with_status.job)

let issue_from_zkapp_command_work_pool ~(partitioner : t) () :
    Partitioned_work.Single.Spec.t option =
  let open Option.Let_syntax in
  let%bind pairing_id, pending_zkapp_command =
    Zkapp_command_job_pool.peek partitioner.zkapp_command_jobs
  in
  let%map spec =
    Pending_Zkapp_command.generate_job_spec pending_zkapp_command
  in
  let job_uuid =
    Partitioned_work.Zkapp_command_job.UUID.Job_UUID
      (Uuid_generator.next_uuid partitioner.uuid_generator)
  in
  let job_with_status =
    Partitioned_work.Zkapp_command_job.{ spec; pairing_id; job_uuid }
    |> Zkapp_command_job_with_status.issue_now
  in
  Sent_job_pool.replace ~id:job_uuid ~job:job_with_status
    partitioner.jobs_sent_by_partitioner ;

  Partitioned_work.Single.Spec.Sub_zkapp_command job_with_status.job

let rec issue_from_first_in_pair ~(partitioner : t) () =
  match partitioner.first_in_pair with
  | Some work ->
      partitioner.first_in_pair <- None ;
      Some
        (convert_single_work_from_selector ~partitioner ~one_or_two:`First ~work)
  | None ->
      None

(* try to issue a single work received from the underlying Work_selector
   `one_or_two` tracks which task is it inside a `One_or_two`*)
and convert_single_work_from_selector ~(partitioner : t)
    ~(one_or_two : [ `First | `Second | `One ])
    ~(work : Selector_work.Single_spec.t) : Partitioned_work.Single.Spec.t =
  match work with
  | Transition (input, witness) as work -> (
      (* WARN: a smilar copy of this exists in `Snark_worker.Worker_impl_prod` *)
      match witness.transaction with
      | Command (Zkapp_command zkapp_command) -> (
          match
            Async.Thread_safe.block_on_async (fun () ->
                Shared.extract_zkapp_segment_works
                  ~m:partitioner.transaction_snark ~input ~witness
                  ~zkapp_command )
          with
          | Ok (Ok (_ :: _ as all)) ->
              let pairing_id =
                Partitioned_work.Pairing.
                  { one_or_two
                  ; pair_uuid =
                      Some
                        (Pairing_UUID
                           (Uuid_generator.next_uuid partitioner.uuid_generator)
                        )
                  }
              in
              let unscheduled_segments =
                all
                |> List.map ~f:(fun (witness, spec, statement) ->
                       Partitioned_work.Zkapp_command_job.Spec.Segment
                         { statement; witness; spec } )
                |> Queue.of_list
              in
              let pending_mergable_proofs = Deque.create () in
              let merge_remaining = Queue.length unscheduled_segments - 1 in
              let pending_zkapp_command =
                Pending_Zkapp_command.
                  { unscheduled_segments
                  ; pending_mergable_proofs
                  ; merge_remaining
                  ; spec = work
                  ; elapsed = Time.Span.zero
                  }
              in
              assert (
                phys_equal `Ok
                  (Zkapp_command_job_pool.attempt_add ~key:pairing_id
                     ~job:pending_zkapp_command partitioner.zkapp_command_jobs ) ) ;
              issue_job_from_partitioner ~partitioner ()
              |> Option.value_exn
                   ~message:
                     "FATAL: we already inserted work into partitioner so this \
                      shouldn't happen"
          | Ok (Ok []) ->
              failwith "No witness generated"
          | Ok (Error e) ->
              failwith (Error.to_string_hum e)
          | Error e ->
              failwith (Exn.to_string e) )
      | Command (Signed_command _) | Fee_transfer _ | Coinbase _ ->
          Regular (work, { one_or_two; pair_uuid = None }) )
  | Merge _ ->
      Regular (work, { one_or_two; pair_uuid = None })

and issue_job_from_partitioner ~(partitioner : t) () :
    Partitioned_work.Single.Spec.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ reissue_old_task ~partitioner
    ; issue_from_first_in_pair ~partitioner
    ; issue_from_zkapp_command_work_pool ~partitioner
    ]

(* WARN: this should only be called if partitioner.first_in_pair is None *)
let consume_job_from_selector ~(partitioner : t)
    ~(work : Selector_work.Single_spec.t One_or_two.t) () :
    Partitioned_work.Single.Spec.t =
  match work with
  | `One work ->
      convert_single_work_from_selector ~partitioner ~one_or_two:`One ~work
  | `Two (work_fst, work_snd) ->
      assert (phys_equal None partitioner.first_in_pair) ;
      partitioner.first_in_pair <- Some work_fst ;
      convert_single_work_from_selector ~partitioner ~one_or_two:`Second
        ~work:work_snd

(* Logics for work submitting *)

let submit_directly_to_work_selector ~(result : Partitioned_work.Result.t)
    ~(callback : Selector_work.Result.t -> unit) () =
  let open Option.Let_syntax in
  let%map result = Partitioned_work.Result.to_selector_result result in
  callback result
