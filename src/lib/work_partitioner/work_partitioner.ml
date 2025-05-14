open Core_kernel
module Snark_worker_shared = Snark_worker_shared
module Work = Snark_work_lib
module Zkapp_command_job_pool =
  Job_pool.Make (Work.ID.Zkapp) (Pending_zkapp_command)
module Sent_zkapp_job_pool =
  Job_pool.Make (Work.ID.Sub_zkapp) (Work.Spec.Sub_zkapp)
module Sent_single_job_pool = Job_pool.Make (Work.ID.Single) (Work.Spec.Single)

module Pairing_status = struct
  type t =
    | None of
        { prover : Signature_lib.Public_key.Compressed.t
        ; fee_of_full : Currency.Fee.t
        }
    | Single of Mergable_single_work.t
end

type t =
  { logger : Logger.t
  ; transaction_snark : (module Transaction_snark.S)
        (* WARN: we're mixing ID for `pairing_pool` and `zkapp_command_jobs.
           Should be fine *)
  ; id_generator : Id_generator.t (* NOTE: Fields for pooling *)
  ; pairing_pool : (int64, Pairing_status.t) Hashtbl.t
        (* if one single work from underlying Work_selector is completed but
           not the other. throw it here. *)
  ; zkapp_command_jobs : Zkapp_command_job_pool.t
        (* NOTE: Fields for reissue pooling*)
  ; reassignment_timeout : Time.Span.t
  ; zkapp_jobs_sent_by_partitioner : Sent_zkapp_job_pool.t
  ; single_jobs_sent_by_partitioner : Sent_single_job_pool.t
        (* NOTE: we're assuming everything in this queue is sorted in time from old to new.
           So queue head is the oldest task.
        *)
  ; mutable tmp_slot : (Work.Spec.Single.t * Work.ID.Single.t) option
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
  ; id_generator = Id_generator.create ~logger
  ; pairing_pool = Hashtbl.create (module Int64)
  ; zkapp_command_jobs = Zkapp_command_job_pool.create ()
  ; reassignment_timeout
  ; zkapp_jobs_sent_by_partitioner = Sent_zkapp_job_pool.create ()
  ; single_jobs_sent_by_partitioner = Sent_single_job_pool.create ()
  ; tmp_slot = None
  }

let epoch_now () = Time.(now () |> to_span_since_epoch)

(* Logics for work requesting *)
let reissue_old_zkapp_job ~(partitioner : t) () : Work.Spec.Full.t option =
  let%map.Option job =
    Sent_zkapp_job_pool.reissue_if_old
      partitioner.zkapp_jobs_sent_by_partitioner
      ~reassignment_timeout:partitioner.reassignment_timeout
  in
  Work.Spec.Full.Poly.Sub_zkapp_command { job; data = () }

let reissue_old_single_job ~(partitioner : t) () : Work.Spec.Full.t option =
  let%map.Option job =
    Sent_single_job_pool.reissue_if_old
      partitioner.single_jobs_sent_by_partitioner
      ~reassignment_timeout:partitioner.reassignment_timeout
  in
  Work.Spec.Full.Poly.Single { job; data = () }

let issue_from_zkapp_command_work_pool ~(partitioner : t) () :
    Work.Spec.Full.t option =
  let open Option.Let_syntax in
  let attempt_issue_from_pending (zkapp_id : Work.ID.Zkapp.t)
      (pending : Pending_zkapp_command.t) =
    let%map spec = Pending_zkapp_command.generate_job_spec pending in
    let job_id =
      Work.ID.Sub_zkapp.of_zkapp
        ~job_id:(Id_generator.next_id partitioner.id_generator ())
        zkapp_id
    in
    let issued_since_unix_epoch = epoch_now () in
    let job = Work.With_status.{ spec; job_id; issued_since_unix_epoch } in
    Sent_zkapp_job_pool.replace ~id:job_id ~job
      partitioner.zkapp_jobs_sent_by_partitioner ;

    Work.Spec.Full.Poly.Sub_zkapp_command { job; data = () }
  in

  Zkapp_command_job_pool.fold_until ~init:None
    ~f:(fun _ job ->
      match attempt_issue_from_pending job.job_id job.spec with
      | None ->
          { slashed = false; action = `Continue None }
      | Some spec ->
          { slashed = false; action = `Stop (Some spec) } )
    ~finish:Fn.id partitioner.zkapp_command_jobs

let rec issue_from_tmp_slot ~(partitioner : t) () =
  match partitioner.tmp_slot with
  | Some spec ->
      partitioner.tmp_slot <- None ;
      let single_spec, pairing = spec in
      Some
        (convert_single_work_from_selector ~partitioner ~single_spec ~pairing)
  | None ->
      None

(* try to issue a single work received from the underlying Work_selector
   `one_or_two` tracks which task is it inside a `One_or_two`*)
and convert_single_work_from_selector ~(partitioner : t) ~single_spec ~pairing :
    Work.Spec.Full.t =
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
                       Work.Spec.Sub_zkapp.Poly.Segment
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
              let zkapp_id =
                Work.ID.Zkapp.of_single
                  (Id_generator.next_id partitioner.id_generator)
                  pairing
              in
              let pending_zkapp_command_job =
                Work.With_status.
                  { spec = pending_zkapp_command
                  ; job_id = zkapp_id
                  ; issued_since_unix_epoch = epoch_now ()
                  }
              in
              assert (
                phys_equal `Ok
                  (Zkapp_command_job_pool.attempt_add ~key:zkapp_id
                     ~job:pending_zkapp_command_job
                     partitioner.zkapp_command_jobs ) ) ;
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
            { job =
                Work.With_status.
                  { spec = single_spec
                  ; job_id = pairing
                  ; issued_since_unix_epoch = epoch_now ()
                  }
            ; data = ()
            } )
  | Merge _ ->
      Single
        { job =
            Work.With_status.
              { spec = single_spec
              ; job_id = pairing
              ; issued_since_unix_epoch = epoch_now ()
              }
        ; data = ()
        }

and issue_job_from_partitioner ~(partitioner : t) () : Work.Spec.Full.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ reissue_old_zkapp_job ~partitioner
    ; reissue_old_single_job ~partitioner
    ; issue_from_zkapp_command_work_pool ~partitioner
    ; issue_from_tmp_slot ~partitioner
    ]

(* WARN: this should only be called if partitioner.first_in_pair is None *)
let consume_job_from_selector ~(partitioner : t)
    ~(spec : Work.Spec.Single.t One_or_two.t) () : Work.Spec.Full.t =
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
  let Mergable_single_work.{ which_half; _ } = this_single in
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

        result := Some work ;
        None
    | None ->
        Some this_single ) ;
  Processed !result

let submit_into_pending_zkapp_command ~partitioner
    ~spec:({ pairing; job_id; _ } : Work.Partitioned.Zkapp_command_job.t)
    ~metric:({ proof; elapsed } : Work.Partitioned.Proof_with_metric.t)
    ~(prover : Signature_lib.Public_key.Compressed.t) =
  let returns = ref SchemeUnmatched in
  let process pending =
    Pending_zkapp_command.submit_proof ~proof ~elapsed pending ;

    if 0 = pending.merge_remaining then
      let final_proof =
        Deque.dequeue_front_exn pending.pending_mergable_proofs
      in
      let Work.Partitioned.Pairing.Sub_zkapp.{ which_one; id } = pairing in
      let metric = (pending.elapsed, `Transition) in

      match which_one with
      | `One ->
          let result : Work.Selector.Result.t =
            { proofs = `One final_proof
            ; metrics = `One (pending.elapsed, `Transition)
            ; spec =
                { instances = `One pending.spec; fee = pending.fee_of_full }
            ; prover
            }
          in

          returns := Processed (Some result)
      | (`First | `Second) as which_half ->
          let this_single =
            Mergable_single_work.
              { which_half
              ; proof
              ; metric
              ; spec = pending.spec
              ; prover
              ; common =
                  { issued_since_unix_epoch = epoch_now ()
                  ; fee_of_full = pending.fee_of_full
                  }
              }
          in

          returns := submit_single ~partitioner ~this_single ~id
    else returns := Processed None
  in
  let slash_or_process :
         Work.Partitioned.Zkapp_command_job.t option
      -> Work.Partitioned.Zkapp_command_job.t option = function
    | None ->
        printf
          "Worker submit a work that's already slashed from sent job pool, \
           meaning it's completed, ignoring" ;
        returns := Slashed ;
        None
    | Some _ -> (
        match
          Zkapp_command_job_pool.find partitioner.zkapp_command_jobs pairing
        with
        | None ->
            printf
              "Worker submit a work that's already slashed from pending zkapp \
               command pool, meaning it's completed, ignoring " ;
            returns := Slashed ;
            None
        | Some pending ->
            process pending ; None )
  in

  Sent_job_pool.change ~id:job_id ~f:slash_or_process
    partitioner.jobs_sent_by_partitioner ;
  !returns

let submit_partitioned_work ~(result : Work.Partitioned.Result.t)
    ~(callback : Work.Selector.Result.t -> unit) ~(partitioner : t) =
  let submit_result =
    match result with
    | { data =
          Work.Partitioned.Spec.Poly.Old
            { instances; common = { fee_of_full = fee; _ } }
      ; prover
      } ->
        let to_submit =
          Work.Partitioned.construct_selector_result ~instances ~fee ~prover
        in
        Processed (Some to_submit)
    | { data =
          Work.Partitioned.Spec.Poly.Single
            { single_spec
            ; pairing = `One
            ; metric
            ; common = { fee_of_full = fee; _ }
            }
      ; prover
      } ->
        let instances = `One (single_spec, metric) in
        let to_submit =
          Work.Partitioned.construct_selector_result ~instances ~fee ~prover
        in
        Processed (Some to_submit)
    | { data =
          Work.Partitioned.Spec.Poly.Single
            { single_spec
            ; pairing = (`First id | `Second id) as first_or_second
            ; metric = { proof; elapsed }
            ; common
            }
      ; prover
      } ->
        let which_half =
          match first_or_second with `First _ -> `First | `Second _ -> `Second
        in

        let metric =
          match single_spec with
          | Work.Work.Single.Spec.Transition (_, _) ->
              (elapsed, `Transition)
          | Work.Work.Single.Spec.Merge (_, _, _) ->
              (elapsed, `Merge)
        in
        let this_single =
          Mergable_single_work.
            { which_half; proof; metric; spec = single_spec; prover; common }
        in
        submit_single ~partitioner ~this_single ~id
    | { data = Work.Partitioned.Spec.Poly.Sub_zkapp_command { spec; metric }
      ; prover
      } ->
        submit_into_pending_zkapp_command ~partitioner ~spec ~metric ~prover
  in
  match submit_result with
  | SchemeUnmatched ->
      `SchemeUnmatched
  | Slashed ->
      `Slashed
  | Processed (Some result) ->
      callback result ; `Ok
  | Processed None ->
      `Ok
