open Core
module Snark_worker_shared = Snark_worker_shared
module Work = Snark_work_lib
module Zkapp_command_job_with_status =
  With_job_status.Make (Work.Partitioned.Zkapp_command_job)
module Zkapp_command_job_pool =
  Job_pool.Make (Work.Partitioned.Pairing) (Pending_zkapp_command)
module Sent_job_pool =
  Job_pool.Make
    (Work.Partitioned.Zkapp_command_job.ID)
    (Zkapp_command_job_with_status)

type t =
  { logger : Logger.t
  ; transaction_snark : (module Transaction_snark.S)
        (* WARN: we're mixing ID for `pairing_pool` and `zkapp_command_jobs.
           Should be fine *)
  ; id_generator : Id_generator.t (* NOTE: Fields for pooling *)
  ; pairing_pool :
      (Work.Partitioned.Pairing.ID.t, Mergable_single_work.t) Hashtbl.t
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
  ; mutable tmp_slot :
      (Work.Selector.Single.Spec.t * Work.Partitioned.Pairing.t * Currency.Fee.t)
      option
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
  ; id_generator = Id_generator.create ()
  ; pairing_pool = Hashtbl.create (module Work.Partitioned.Pairing.ID)
  ; zkapp_command_jobs = Zkapp_command_job_pool.create ()
  ; reassignment_timeout
  ; jobs_sent_by_partitioner = Sent_job_pool.create ()
  ; tmp_slot = None
  }

(* Logics for work requesting *)
let reissue_old_task ~(partitioner : t) () : Work.Partitioned.Spec.t option =
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
      let spec = job_with_status.job in
      Some (Sub_zkapp_command { spec; metric = () })

let issue_from_zkapp_command_work_pool ~(partitioner : t) () :
    Work.Partitioned.Spec.t option =
  let open Option.Let_syntax in
  let%bind pairing, pending_zkapp_command =
    Zkapp_command_job_pool.peek partitioner.zkapp_command_jobs
  in
  let%map spec =
    Pending_zkapp_command.generate_job_spec pending_zkapp_command
  in
  let job_id =
    Work.Partitioned.Zkapp_command_job.ID.Job_ID
      (Id_generator.next_id partitioner.id_generator)
  in
  let job_with_status =
    Work.Partitioned.Zkapp_command_job.{ spec; pairing; job_id }
    |> Zkapp_command_job_with_status.issue_now
  in
  Sent_job_pool.replace ~id:job_id ~job:job_with_status
    partitioner.jobs_sent_by_partitioner ;

  let spec = job_with_status.job in
  Work.Partitioned.Spec.Poly.Sub_zkapp_command { spec; metric = () }

let rec issue_from_tmp_slot ~(partitioner : t) () =
  match partitioner.tmp_slot with
  | Some spec ->
      partitioner.tmp_slot <- None ;
      let single_spec, pairing, fee_of_full = spec in
      Some
        (convert_single_work_from_selector ~partitioner ~single_spec ~pairing
           ~fee_of_full )
  | None ->
      None

(* try to issue a single work received from the underlying Work_selector
   `one_or_two` tracks which task is it inside a `One_or_two`*)
and convert_single_work_from_selector ~(partitioner : t) ~single_spec ~pairing
    ~fee_of_full : Work.Partitioned.Spec.t =
  match single_spec with
  | Transition (input, witness) as work -> (
      (* WARN: a smilar copy of this exists in `Snark_worker.Worker_impl_prod` *)
      match witness.transaction with
      | Command (Zkapp_command zkapp_command) -> (
          match
            Async.Thread_safe.block_on_async (fun () ->
                Snark_worker_shared.extract_zkapp_segment_works
                  ~m:partitioner.transaction_snark ~input ~witness
                  ~zkapp_command )
          with
          | Ok (Ok (_ :: _ as all)) ->
              let unscheduled_segments =
                all
                |> List.map ~f:(fun (witness, spec, statement) ->
                       Work.Partitioned.Zkapp_command_job.Spec.Segment
                         { statement; witness; spec } )
                |> Queue.of_list
              in
              let pending_mergable_proofs = Deque.create () in
              let merge_remaining = Queue.length unscheduled_segments - 1 in
              let pending_zkapp_command =
                Pending_zkapp_command.
                  { unscheduled_segments
                  ; pending_mergable_proofs
                  ; merge_remaining
                  ; spec = work
                  ; elapsed = Time.Span.zero
                  }
              in
              assert (
                phys_equal `Ok
                  (Zkapp_command_job_pool.attempt_add ~key:pairing
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
          Single { single_spec; pairing; fee_of_full; metric = () } )
  | Merge _ ->
      Single { single_spec; pairing; fee_of_full; metric = () }

and issue_job_from_partitioner ~(partitioner : t) () :
    Work.Partitioned.Spec.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ reissue_old_task ~partitioner
    ; issue_from_tmp_slot ~partitioner
    ; issue_from_zkapp_command_work_pool ~partitioner
    ]

(* WARN: this should only be called if partitioner.first_in_pair is None *)
let consume_job_from_selector ~(partitioner : t) ~(spec : Work.Selector.Spec.t)
    () : Work.Partitioned.Spec.t =
  let fee_of_full = spec.fee in
  match spec.instances with
  | `One single_spec ->
      convert_single_work_from_selector ~partitioner ~single_spec
        ~pairing:(`One None) ~fee_of_full
  | `Two (spec1, spec2) ->
      assert (phys_equal None partitioner.tmp_slot) ;
      let id = Id_generator.next_id partitioner.id_generator in
      let pairing1 : Work.Partitioned.Pairing.t = `First (Pairing_ID id) in
      let pairing2 : Work.Partitioned.Pairing.t = `Second (Pairing_ID id) in
      partitioner.tmp_slot <- Some (spec1, pairing1, fee_of_full) ;
      convert_single_work_from_selector ~partitioner ~single_spec:spec2
        ~pairing:pairing2 ~fee_of_full

(* Logics for work submitting *)

type submit_result =
  | SchemeUnmatched
  | Slashed
  | Processed of Work.Selector.Result.t option
(* If the `option` in Processed is present, it indicates we need to submit to the underlying selector *)
