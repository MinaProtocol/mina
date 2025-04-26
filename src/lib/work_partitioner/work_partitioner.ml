open Core_kernel
module Snark_worker_shared = Snark_worker_shared
module Work = Snark_work_lib
module Zkapp_command_job_pool =
  Job_pool.Make (Work.Partitioned.Pairing.Sub_zkapp) (Pending_zkapp_command)
module Sent_job_pool =
  Job_pool.Make
    (Work.Partitioned.Zkapp_command_job.ID)
    (Work.Partitioned.Zkapp_command_job)

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
      ( Work.Selector.Single.Spec.t
      * Work.Partitioned.Pairing.Single.t
      * Currency.Fee.t )
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

let epoch_now () = Time.(now () |> to_span_since_epoch)

(* Logics for work requesting *)
let reissue_old_task ~(partitioner : t) () : Work.Partitioned.Spec.t option =
  let job_is_old (job : Work.Partitioned.Zkapp_command_job.t) : bool =
    let issued = Time.of_span_since_epoch job.common.issued_since_unix_epoch in
    let delta = Time.(diff (now ()) issued) in
    Time.Span.( > ) delta partitioner.reassignment_timeout
  in
  match
    Sent_job_pool.take_first_ready ~pred:job_is_old
      partitioner.jobs_sent_by_partitioner
  with
  | None ->
      None
  | Some (id, job) ->
      let issued_since_unix_epoch = epoch_now () in
      let reissued =
        { job with common = { job.common with issued_since_unix_epoch } }
      in
      Sent_job_pool.replace ~id ~job:reissued
        partitioner.jobs_sent_by_partitioner ;
      Some (Sub_zkapp_command { spec = reissued; metric = () })

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
  let fee_of_full = pending_zkapp_command.fee_of_full in
  let issued_since_unix_epoch = epoch_now () in
  let spec =
    Work.Partitioned.Zkapp_command_job.Poly.
      { spec
      ; pairing
      ; job_id
      ; common = { fee_of_full; issued_since_unix_epoch }
      }
  in
  Sent_job_pool.replace ~id:job_id ~job:spec
    partitioner.jobs_sent_by_partitioner ;

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
                let witness =
                  Transaction_witness.read_all_proofs_from_disk witness
                in
                Snark_worker_shared.extract_zkapp_segment_works
                  ~m:partitioner.transaction_snark ~input ~witness
                  ~zkapp_command )
          with
          | Ok (Ok (_ :: _ as all)) ->
              let unscheduled_segments =
                all
                |> List.map ~f:(fun (witness, spec, statement) ->
                       Work.Partitioned.Zkapp_command_job.Spec.Poly.Segment
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
                  ; fee_of_full
                  }
              in
              let pairing =
                Work.Partitioned.Pairing.Sub_zkapp.of_single
                  (fun () ->
                    Pairing_ID (Id_generator.next_id partitioner.id_generator)
                    )
                  pairing
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
          Single
            { single_spec
            ; pairing
            ; metric = ()
            ; common = { fee_of_full; issued_since_unix_epoch = epoch_now () }
            } )
  | Merge _ ->
      Single
        { single_spec
        ; pairing
        ; metric = ()
        ; common = { fee_of_full; issued_since_unix_epoch = epoch_now () }
        }

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
      convert_single_work_from_selector ~partitioner ~single_spec ~pairing:`One
        ~fee_of_full
  | `Two (spec1, spec2) ->
      assert (phys_equal None partitioner.tmp_slot) ;
      let id = Id_generator.next_id partitioner.id_generator in
      let pairing1 : Work.Partitioned.Pairing.Single.t =
        `First (Pairing_ID id)
      in
      let pairing2 : Work.Partitioned.Pairing.Single.t =
        `Second (Pairing_ID id)
      in
      partitioner.tmp_slot <- Some (spec1, pairing1, fee_of_full) ;
      convert_single_work_from_selector ~partitioner ~single_spec:spec2
        ~pairing:pairing2 ~fee_of_full

let request_from_selector_and_consume_by_partitioner ~(partitioner : t)
    ~(selection_method : (module Work_selector.Selection_method_intf))
    ~(selector : Work_selector.State.t) ~(logger : Logger.t)
    ~(fee : Currency.Fee.t) ~snark_pool () =
  let (module Work_selection_method) = selection_method in
  let open Core_kernel in
  let open Option.Let_syntax in
  let%map instances =
    Work_selection_method.work ~logger ~fee ~snark_pool selector
  in
  let spec : Work.Selector.Spec.t = { instances; fee } in

  consume_job_from_selector ~partitioner ~spec ()

let request_partitioned_work
    ~(selection_method : (module Work_selector.Selection_method_intf))
    ~(logger : Logger.t) ~(fee : Currency.Fee.t)
    ~(snark_pool : Work_selector.snark_pool) ~(selector : Work_selector.State.t)
    ~(partitioner : t) : Work.Partitioned.Spec.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ issue_job_from_partitioner ~partitioner
    ; request_from_selector_and_consume_by_partitioner ~partitioner
        ~selection_method ~selector ~logger ~fee ~snark_pool
    ]

(* Logics for work submitting *)

type submit_result =
  | SchemeUnmatched
  | Slashed
  | Processed of Work.Selector.Result.t option
(* If the `option` in Processed is present, it indicates we need to submit to the underlying selector *)

let submit_single ~partitioner ~this_single ~id =
  let Mergable_single_work.{ which_half; common; _ } = this_single in
  let issued = Time.of_span_since_epoch common.issued_since_unix_epoch in
  let delta = Time.(diff (now ()) issued) in
  if Time.Span.( > ) delta partitioner.reassignment_timeout then
    (* This is how we guarantee there's no ID being repeated. We should remove
       logic on slashing old work submitted in Work Selector though, as they're
       now redundant.
    *)
    Slashed
  else
    let result = ref None in
    Hashtbl.change partitioner.pairing_pool id ~f:(function
      | Some other_single ->
          let work =
            match which_half with
            | `First ->
                Mergable_single_work.merge_to_one_result_exn this_single
                  other_single
            | `Second ->
                Mergable_single_work.merge_to_one_result_exn other_single
                  this_single
          in

          let (Pairing_ID id) = id in
          Id_generator.recycle_id partitioner.id_generator id ;
          result := Some work ;
          None
      | None ->
          Some this_single ) ;
    Processed !result
