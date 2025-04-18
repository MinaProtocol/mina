(* work partitioner split the work produced by a Work_selector into smaller tasks,
   and issue them to the actual worker. It's also in charge of aggregating
   the response from worker. We have this layer because we don't want to
   touch the Work_selector and break the GraphQL API.

   Ideally, we should refactor so this integrates into `Work_selector`.
*)

open Core_kernel
open Snark_work_lib.Work.Wire

(* A generic function that try on each function in the list until we got an
   `Some _` and return it *)
let attempt_these =
  List.fold_until ~init:None ~finish:Fn.id ~f:(fun _ this_attempt ->
      match this_attempt () with
      | Some result ->
          Stop (Some result)
      | None ->
          Continue None )

module UUID_generator = struct
  type t = { reusable_uuids : int Queue.t; mutable last_uuid : int }

  let create () = { reusable_uuids = Queue.create (); last_uuid = 0 }

  let next_uuid (t : t) : int =
    match Queue.dequeue t.reusable_uuids with
    | Some uuid ->
        uuid
    | None ->
        t.last_uuid <- t.last_uuid + 1 ;
        t.last_uuid

  let recycle_uuid (t : t) (uuid : int) = Queue.enqueue t.reusable_uuids uuid
end

module Zkapp_command_job_with_status = struct
  type t = { job : Zkapp_command_job.t; status : Work_lib.Job_status.t }

  let issue_now (job : Zkapp_command_job.t) : t =
    { job; status = Assigned (Time.now ()) }
end

(* result from Work_partitioner *)
module Partitioned_work = struct
  type t = Single.Spec.t

  let of_job_with_status (job_with_status : Zkapp_command_job_with_status.t) : t
      =
    Single.Spec.Stable.Latest.Sub_zkapp_command job_with_status.job
end

(* A single work in Work_selector's perspective *)
module Single_work_with_data = struct
  type t =
    { which_half : [ `First | `Second ]
    ; proof : Ledger_proof.t
    ; metric : Core.Time.Span.t
    ; spec :
        ( Transaction_witness.t
        , Ledger_proof.t )
        Snark_work_lib.Work.Compact.Single.Spec.t
    ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
    }
end

module Pending_Zkapp_command = struct
  type t =
    { unscheduled_segments : Zkapp_command_job.Spec.t Queue.t
          (* we may need to insert proofs to merge back to the queue, hence a Deque *)
    ; pending_mergable_proofs : Ledger_proof.t Deque.t
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
    Zkapp_command_job.Spec.Merge { proof1; proof2 }

  let generate_segment ~(t : t) () =
    let open Option.Let_syntax in
    let%map segment = Queue.dequeue t.unscheduled_segments in
    segment

  let generate_job_spec (t : t) : Zkapp_command_job.Spec.t option =
    attempt_these [ generate_merge ~t; generate_segment ~t ]
end

(* NOTE: Maybe this is reusable with Work Selector as they also have reissue mechanism *)
module JobPool (ID : Hashtbl.Key) (Job : T) = struct
  type job_item = Job.t option ref

  type t =
    { queue : (ID.t * job_item) Queue.t (* For iteration  *)
    ; table : (ID.t, job_item) Hashtbl.t (* For marking task as done *)
    }

  let create () =
    { queue = Queue.create (); table = Hashtbl.create (module ID) }

  let rec peek (t : t) =
    match Queue.peek t.queue with
    | None ->
        None
    | Some (_, { contents = None }) ->
        (* Task done *)
        ignore (Queue.dequeue_exn t.queue : ID.t * job_item) ;
        peek t
    | Some (id, { contents = Some pending }) ->
        Some (id, pending)

  let rec spit_one_if ~(pred : Job.t -> bool) (t : t) =
    match Queue.peek t.queue with
    | None ->
        None
    | Some (_, { contents = None }) ->
        (* Task done *)
        ignore (Queue.dequeue_exn t.queue : ID.t * job_item) ;
        spit_one_if ~pred t
    | Some (id, { contents = Some pending }) ->
        if pred pending then (
          ignore (Queue.dequeue_exn t.queue : ID.t * job_item) ;
          Some (id, pending) )
        else None

  (* will leave untouched if duplicated*)
  let add ~(key : ID.t) ~(job : Job.t) (t : t) =
    let data = ref (Some job) in
    Queue.enqueue t.queue (key, data) ;
    Hashtbl.add ~key ~data t.table

  (* will overwrite*)
  let set ~(key : ID.t) ~(job : Job.t) (t : t) =
    let data = ref (Some job) in
    Queue.enqueue t.queue (key, data) ;
    Hashtbl.set ~key ~data t.table

  let slash (t : t) (id : ID.t) =
    match Hashtbl.find_and_remove t.table id with
    | None ->
        None
    | Some job_item ->
        let result = !job_item in
        job_item := None ;
        Some result
end

module Zkapp_command_job_pool = JobPool (Pairing) (Pending_Zkapp_command)
module Sent_job_pool =
  JobPool (Zkapp_command_job.UUID) (Zkapp_command_job_with_status)

type t =
  { logger : Logger.t
  ; transaction_snark : (module Transaction_snark.S)
        (* WARN: we're mixing UUID for `pairing_pool` and `zkapp_command_jobs.
           Should be fine *)
  ; uuid_generator : UUID_generator.t ref (* NOTE: Fields for pooling *)
  ; pairing_pool : (Pairing.UUID.t, Single_work_with_data.t) Hashtbl.t
        (* if one single work from underlying Work_selector is completed but
           not the other. throw it here. *)
  ; zkapp_command_jobs : Zkapp_command_job_pool.t
        (* NOTE: Fields for reissue pooling*)
  ; reassignment_wait : int
  ; jobs_sent_by_partitioner : Sent_job_pool.t
        (* we only track tasks created by a Work_partitioner here. For reissue
           of regular jobs, we still turn to the underlying Work_selector *)
        (* WARN: we're assuming everything in this queue is sorted in time from old to new.
           So queue head is the oldest task.
        *)
  ; mutable first_in_pair :
      (Work_lib.work * Mina_base.Sok_message.Digest.t) option
        (* When receving a `Two works from the underlying Work_selector, store one of them here,
           so we could issue them to another worker.
        *)
  }

let create ~(reassignment_wait : int) ~(logger : Logger.t) : t =
  let module M = Transaction_snark.Make (struct
    let constraint_constants = Genesis_constants.Compiled.constraint_constants

    let proof_level = Genesis_constants.Compiled.proof_level
  end) in
  { logger
  ; transaction_snark = (module M)
  ; uuid_generator = ref (UUID_generator.create ())
  ; pairing_pool = Hashtbl.create (module Pairing.UUID)
  ; zkapp_command_jobs = Zkapp_command_job_pool.create ()
  ; reassignment_wait
  ; jobs_sent_by_partitioner = Sent_job_pool.create ()
  ; first_in_pair = None
  }

let reissue_old_task ~(partitioner : t) () : Partitioned_work.t option =
  let job_is_old (job : Zkapp_command_job_with_status.t) : bool =
    Work_lib.Job_status.is_old ~now:(Time.now ())
      ~reassignment_wait:partitioner.reassignment_wait job.status
  in
  match
    Sent_job_pool.spit_one_if ~pred:job_is_old
      partitioner.jobs_sent_by_partitioner
  with
  | None ->
      None
  | Some (key, job_with_status) ->
      let reissued = { job_with_status with status = Assigned (Time.now ()) } in
      Sent_job_pool.set ~key ~job:reissued partitioner.jobs_sent_by_partitioner ;
      Some (Partitioned_work.of_job_with_status job_with_status)

let issue_from_zkapp_command_work_pool ~(partitioner : t) () :
    Partitioned_work.t option =
  let open Option.Let_syntax in
  let%bind pairing_id, pending_zkapp_command =
    Zkapp_command_job_pool.peek partitioner.zkapp_command_jobs
  in
  let%map spec =
    Pending_Zkapp_command.generate_job_spec pending_zkapp_command
  in
  let job_uuid =
    Zkapp_command_job.UUID.Job_UUID
      (UUID_generator.next_uuid !(partitioner.uuid_generator))
  in
  let job_with_status =
    Zkapp_command_job.{ spec; pairing_id; job_uuid }
    |> Zkapp_command_job_with_status.issue_now
  in
  Sent_job_pool.set ~key:job_uuid ~job:job_with_status
    partitioner.jobs_sent_by_partitioner ;
  Partitioned_work.of_job_with_status job_with_status

let rec issue_from_first_in_pair ~(partitioner : t) () =
  match partitioner.first_in_pair with
  | Some (work, sok_digest) ->
      partitioner.first_in_pair <- None ;
      Some
        (convert_single_work_from_selector ~partitioner ~sok_digest
           ~one_or_two:`First ~work )
  | None ->
      None

(* try to issue a single work received from the underlying Work_selector
   `one_or_two` tracks which task is it inside a `One_or_two`*)
(* TODO: remove sok_digest *)
and convert_single_work_from_selector ~(partitioner : t) ~sok_digest:_
    ~(one_or_two : [ `First | `Second | `One ]) ~(work : Work_lib.work) :
    Partitioned_work.t =
  match work with
  | Snark_work_lib.Work.Compact.Single.Spec.Transition (input, witness) as work
    -> (
      (* WARN: a smilar copy of this exists in `Snark_worker.Worker_impl_prod` *)
      match
        Mina_transaction.Transaction.read_all_proofs_from_disk
          witness.transaction
      with
      | Command (Zkapp_command zkapp_command) -> (
          match
            Async.Thread_safe.block_on_async (fun () ->
                Shared.extract_zkapp_segment_works partitioner.transaction_snark
                  input witness zkapp_command )
          with
          | Ok (Ok (_ :: _ as all)) ->
              let pairing_id =
                Pairing.
                  { one_or_two
                  ; pair_uuid =
                      Pairing_UUID
                        (UUID_generator.next_uuid !(partitioner.uuid_generator))
                  }
              in
              let unscheduled_segments =
                all
                |> List.map ~f:(fun (witness, spec, statement) ->
                       Zkapp_command_job.Spec.Segment
                         { statement; witness; spec } )
                |> Queue.of_list
              in
              let pending_mergable_proofs = Deque.create () in
              let pending_zkapp_command =
                Pending_Zkapp_command.
                  { unscheduled_segments; pending_mergable_proofs }
              in
              assert (
                phys_equal `Ok
                  (Zkapp_command_job_pool.add ~key:pairing_id
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
          Single.Spec.Stable.Latest.Regular
            (work, { one_or_two; pair_uuid = Pairing.UUID.ignored }) )
  | Merge _ ->
      Single.Spec.Stable.Latest.Regular
        (work, { one_or_two; pair_uuid = Pairing.UUID.ignored })

and issue_job_from_partitioner ~(partitioner : t) () : Partitioned_work.t option
    =
  attempt_these
    [ reissue_old_task ~partitioner
    ; issue_from_first_in_pair ~partitioner
    ; issue_from_zkapp_command_work_pool ~partitioner
    ]

(* WARN: this should only be called if partitioner.first_in_pair is None *)
let consume_job_from_selector ~fee ~prover ~(partitioner : t)
    ~(work : Work_lib.work One_or_two.t) () : Partitioned_work.t =
  let message = Mina_base.Sok_message.create ~fee ~prover in
  let sok_digest = Mina_base.Sok_message.digest message in
  match work with
  | `One work ->
      convert_single_work_from_selector ~partitioner ~one_or_two:`One ~work
        ~sok_digest
  | `Two (work_fst, work_snd) ->
      assert (phys_equal None partitioner.first_in_pair) ;
      partitioner.first_in_pair <- Some (work_fst, sok_digest) ;
      convert_single_work_from_selector ~partitioner ~one_or_two:`Second
        ~work:work_snd ~sok_digest
