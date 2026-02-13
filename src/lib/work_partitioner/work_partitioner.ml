open Core_kernel

open struct
  module Work = Snark_work_lib
end

module Snark_worker_shared = Snark_worker_shared
module Single_id_map = Map.Make (Work.Id.Single)
module Sent_zkapp_job_pool =
  Job_pool.Make (Work.Id.Sub_zkapp) (Work.Spec.Sub_zkapp.Stable.Latest)
module Sent_single_job_pool =
  Job_pool.Make (Work.Id.Single) (Work.Spec.Single.Stable.Latest)

type t =
  { logger : Logger.t
  ; transaction_snark : (module Transaction_snark.S)
  ; single_id_gen : Id_generator.t
  ; pairing_pool : (int64, Combining_result.t) Hashtbl.t
        (** if one single work from underlying Work_selector is completed but
           not the other. throw it here. *)
  ; mutable pending_zkapp_commands : Pending_zkapp_command.t Single_id_map.t
        (** This is a map because we need [iteri_until]  *)
  ; reassignment_timeout : Time.Span.t
  ; zkapp_jobs_sent_by_partitioner : Sent_zkapp_job_pool.t
  ; single_jobs_sent_by_partitioner : Sent_single_job_pool.t
  ; mutable tmp_slot :
      (Work.Spec.Single.t * Work.Id.Single.t * Mina_base.Sok_message.t) option
        (** When receving a `Two works from the underlying Work_selector, store
            one of them here, so we could schedule them to another worker. *)
  ; proof_cache_db : Proof_cache_tag.cache_db
  }

let create ~(reassignment_timeout : Time.Span.t) ~(logger : Logger.t)
    ~(proof_cache_db : Proof_cache_tag.cache_db)
    ~(signature_kind : Mina_signature_kind.t) : t =
  let module T = Transaction_snark.Make (struct
    let constraint_constants = Genesis_constants.Compiled.constraint_constants

    let proof_level = Genesis_constants.Compiled.proof_level

    let signature_kind = signature_kind
  end) in
  { logger
  ; transaction_snark = (module T)
  ; single_id_gen = Id_generator.create ~logger
  ; pairing_pool = Hashtbl.create (module Int64)
  ; pending_zkapp_commands = Single_id_map.empty
  ; reassignment_timeout
  ; zkapp_jobs_sent_by_partitioner = Sent_zkapp_job_pool.create ()
  ; single_jobs_sent_by_partitioner = Sent_single_job_pool.create ()
  ; tmp_slot = None
  ; proof_cache_db
  }

(* TODO: Consider remove all works no longer relevant for current frontier,
   this may need changes from underlying work selector. *)
let reschedule_if_old ~reassignment_timeout
    ({ job; scheduled } :
      _ Work.With_job_meta.Stable.Latest.t Job_pool.scheduled ) =
  let delta = Time.(diff (now ()) scheduled) in
  if Time.Span.( > ) delta reassignment_timeout then `Stop_reschedule job
  else `Stop_keep

(* NOTE: below are logics for work requesting *)
let reschedule_old_zkapp_job
    ~partitioner:
      ({ reassignment_timeout; zkapp_jobs_sent_by_partitioner; _ } : t) :
    (Work.Spec.Partitioned.Stable.Latest.t, _) Result.t option =
  let%map.Option { job; _ } =
    Sent_zkapp_job_pool.remove_until_reschedule
      ~f:(reschedule_if_old ~reassignment_timeout)
      zkapp_jobs_sent_by_partitioner
  in
  Ok (Work.Spec.Partitioned.Poly.Sub_zkapp_command job)

let reschedule_old_single_job
    ~partitioner:
      ({ reassignment_timeout; single_jobs_sent_by_partitioner; _ } : t) :
    (Work.Spec.Partitioned.Stable.Latest.t, _) Result.t option =
  let%map.Option { job; _ } =
    Sent_single_job_pool.remove_until_reschedule
      ~f:(reschedule_if_old ~reassignment_timeout)
      single_jobs_sent_by_partitioner
  in
  Ok (Work.Spec.Partitioned.Poly.Single job)

let register_pending_zkapp_command_job ~(id : Work.Id.Single.t)
    ~(partitioner : t) ~range ~sub_zkapp_spec
    ~(pending : Pending_zkapp_command.t) =
  let job_id = Work.Id.Sub_zkapp.of_single ~range id in
  let job =
    Work.With_job_meta.
      { spec = sub_zkapp_spec
      ; job_id
      ; sok_message = (Pending_zkapp_command.zkapp_job pending).sok_message
      }
  in
  Sent_zkapp_job_pool.add_now_exn ~id:job_id ~job
    ~message:
      "Work Partitioner generated a duplicated ID for a subzkapp job that \
       happens to be still used by another job."
    partitioner.zkapp_jobs_sent_by_partitioner ;

  Work.Spec.Partitioned.Poly.Sub_zkapp_command job

let schedule_from_pending_zkapp_command ~(id : Work.Id.Single.t)
    ~(partitioner : t) (pending : Pending_zkapp_command.t) =
  let%map.Option sub_zkapp_spec, range =
    Pending_zkapp_command.next_subzkapp_job_spec pending
  in
  register_pending_zkapp_command_job ~id ~partitioner ~sub_zkapp_spec ~range
    ~pending

let schedule_from_any_pending_zkapp_command ~(partitioner : t) :
    (Work.Spec.Partitioned.Stable.Latest.t, _) Result.t option =
  let spec_generated = ref None in
  (* TODO: Consider remove all works no longer relevant for current frontier,
     this may need changes from underlying work selector. *)
  ignore
    (Single_id_map.iteri_until
       ~f:(fun ~key:id ~data ->
         match schedule_from_pending_zkapp_command ~id ~partitioner data with
         | None ->
             Continue
         | Some spec ->
             spec_generated := Some spec ;
             Stop )
       partitioner.pending_zkapp_commands ) ;
  let%map.Option result = !spec_generated in
  Ok result

let convert_zkapp_command_from_selector ~partitioner ~job ~pairing
    unscheduled_segments =
  let unscheduled_segments =
    Snark_worker_shared.Zkapp_command_inputs.read_all_proofs_from_disk
      unscheduled_segments
    |> Mina_stdlib.Nonempty_list.map ~f:(fun (witness, spec, statement) ->
           Work.Spec.Sub_zkapp.SegmentSpec.Stable.Latest.
             { statement; witness; spec } )
  in
  let pending_zkapp_command, first_segment, first_range =
    Pending_zkapp_command.create_and_yield_segment ~job ~unscheduled_segments
  in
  partitioner.pending_zkapp_commands <-
    Single_id_map.add_exn ~key:pairing ~data:pending_zkapp_command
      partitioner.pending_zkapp_commands ;
  register_pending_zkapp_command_job ~id:pairing ~partitioner ~range:first_range
    ~sub_zkapp_spec:first_segment ~pending:pending_zkapp_command

let convert_single_work_from_selector ~(partitioner : t)
    ~(single_spec : Work.Spec.Single.t) ~sok_message ~pairing :
    (Work.Spec.Partitioned.Stable.Latest.t, _) Result.t =
  let job =
    Work.With_job_meta.{ spec = single_spec; job_id = pairing; sok_message }
  in
  match single_spec with
  | Transition (input, witness) -> (
      match witness.transaction with
      | Command (Zkapp_command zkapp_command) ->
          let witness = Transaction_witness.read_all_proofs_from_disk witness in
          Snark_worker_shared.extract_zkapp_segment_works
            ~m:partitioner.transaction_snark ~input ~witness ~zkapp_command
          |> Result.map
               ~f:
                 (convert_zkapp_command_from_selector ~partitioner ~job ~pairing)
      | Command (Signed_command _) | Fee_transfer _ | Coinbase _ ->
          let job =
            Work.With_job_meta.map
              ~f_spec:Work.Spec.Single.read_all_proofs_from_disk job
          in
          Sent_single_job_pool.add_now_exn ~id:pairing ~job
            ~message:
              "Id generator generated a repeated Id that happens to be \
               occupied by a job in sent single job pool"
            partitioner.single_jobs_sent_by_partitioner ;
          Ok (Single job) )
  | Merge _ ->
      let job =
        Work.With_job_meta.map
          ~f_spec:Work.Spec.Single.read_all_proofs_from_disk job
      in
      Sent_single_job_pool.add_now_exn ~id:pairing ~job
        ~message:
          "Id generator generated a repeated Id that happens to be occupied by \
           a job in sent single job pool"
        partitioner.single_jobs_sent_by_partitioner ;
      Ok (Single job)

let schedule_from_tmp_slot ~(partitioner : t) =
  let%map.Option spec = partitioner.tmp_slot in
  partitioner.tmp_slot <- None ;
  let single_spec, pairing, sok_message = spec in
  convert_single_work_from_selector ~partitioner ~single_spec ~pairing
    ~sok_message

let schedule_job_from_partitioner ~(partitioner : t) :
    (Work.Spec.Partitioned.Stable.Latest.t, _) Result.t option =
  List.find_map ~f:Lazy.force
    [ lazy (reschedule_old_zkapp_job ~partitioner)
    ; lazy (reschedule_old_single_job ~partitioner)
    ; lazy (schedule_from_any_pending_zkapp_command ~partitioner)
    ; lazy (schedule_from_tmp_slot ~partitioner)
    ]

(* WARN: this should only be called if [partitioner.tmp_slot] is None *)
let consume_job_from_selector ~(partitioner : t)
    ~(sok_message : Mina_base.Sok_message.t)
    ~(instances : Work.Spec.Single.t One_or_two.t) :
    (Work.Spec.Partitioned.Stable.Latest.t, _) Result.t =
  let pairing_id = Id_generator.next_id partitioner.single_id_gen () in
  Hashtbl.add_exn partitioner.pairing_pool ~key:pairing_id
    ~data:(Combining_result.of_spec ~sok_message instances) ;

  match instances with
  | `One single_spec ->
      let pairing : Work.Id.Single.t = { which_one = `One; pairing_id } in
      convert_single_work_from_selector ~partitioner ~single_spec ~pairing
        ~sok_message
  | `Two (spec1, spec2) ->
      assert (Option.is_none partitioner.tmp_slot) ;
      let pairing1 : Work.Id.Single.t = { which_one = `First; pairing_id } in
      let pairing2 : Work.Id.Single.t = { which_one = `Second; pairing_id } in
      partitioner.tmp_slot <- Some (spec1, pairing1, sok_message) ;
      convert_single_work_from_selector ~partitioner ~single_spec:spec2
        ~sok_message ~pairing:pairing2

type work_from_selector = Work.Spec.Single.t One_or_two.t option Lazy.t

let request_from_selector_and_consume_by_partitioner ~(partitioner : t)
    ~(work_from_selector : work_from_selector)
    ~(sok_message : Mina_base.Sok_message.t) =
  let%map.Option instances = Lazy.force work_from_selector in
  consume_job_from_selector ~partitioner ~instances ~sok_message

let request_partitioned_work ~(sok_message : Mina_base.Sok_message.t)
    ~(work_from_selector : work_from_selector) ~(partitioner : t) :
    (Work.Spec.Partitioned.Stable.Latest.t, _) Result.t option =
  List.find_map ~f:Lazy.force
    [ lazy (schedule_job_from_partitioner ~partitioner)
    ; lazy
        (request_from_selector_and_consume_by_partitioner ~partitioner
           ~work_from_selector ~sok_message )
    ]

type submit_result =
  | SpecUnmatched
  | Removed
  | Processed of Work.Result.Combined.t option

let submit_into_combining_result ~submitted_result ~partitioner
    ~combining_result ~submitted_half =
  match
    Combining_result.merge_single_result ~submitted_result ~submitted_half
      combining_result
  with
  | Pending new_combining_result ->
      `Pending new_combining_result
  | Done combined ->
      One_or_two.iter
        ~f:(fun { spec = single_spec; elapsed; _ } ->
          Work.Metrics.emit_single_metrics ~logger:partitioner.logger
            ~single_spec ~elapsed )
        combined.results ;
      `Done combined
  | HalfAlreadyInPool ->
      [%log' debug partitioner.logger]
        "Worker submit $result, which is already in the pairing job pool, \
         meaning it's completed by another worker, ignoring"
        ~metadata:
          [ ( "result"
            , Work.Result.Single.Poly.to_yojson
                (const `Null)
                Ledger_proof.to_yojson submitted_result )
          ] ;
      `Removed
  | StructureMismatch { spec } ->
      [%log' warn partitioner.logger]
        "Worker submit $result that doesn't match the $spec in the pairing \
         pool, ignoring"
        ~metadata:
          [ ( "spec"
            , One_or_two.to_yojson
                Work.Spec.Single.(
                  Fn.compose Stable.Latest.to_yojson read_all_proofs_from_disk)
                spec )
          ; ( "result"
            , Work.Result.Single.Poly.to_yojson
                (fun () -> `Null)
                Ledger_proof.to_yojson submitted_result )
          ] ;
      `SpecUnmatched

(** Submits a result of a single job.
    If job was part of the pairing, stores the half submitted in the pairing
    pool and returns [Processed None];
    If the other part was available in the pool, returns
    [Processed (Some result)] and removes the pairing from the pool;
    If pairing pool doesn't contain the job, it's most likely that another
    worker have submitted it previously and it was removed. In this case,
    [Spec_unmatched] is returned. 
    If it's from zkapp pool(by setting [is_from_zkapp]), this function won't 
    try to remove from [single_jobs_sent_by_partitioner] because it didn't enter
    the pool in the first place. 
    *)
let submit_single ~is_from_zkapp ~partitioner
    ~(submitted_result : (unit, Ledger_proof.t) Work.Result.Single.Poly.t)
    ~job_id =
  let Work.Id.Single.{ which_one = submitted_half; pairing_id } = job_id in
  let removed_from_single_pool =
    Sent_single_job_pool.remove ~id:job_id
      partitioner.single_jobs_sent_by_partitioner
    |> Option.is_some
  in
  match Hashtbl.find partitioner.pairing_pool pairing_id with
  | Some combining_result when removed_from_single_pool || is_from_zkapp -> (
      match
        submit_into_combining_result ~submitted_result ~partitioner
          ~combining_result ~submitted_half
      with
      | `Pending pending ->
          Hashtbl.set ~key:pairing_id ~data:pending partitioner.pairing_pool ;
          Processed None
      | `Done result ->
          Hashtbl.remove partitioner.pairing_pool pairing_id ;
          Processed (Some result)
      | `Removed ->
          Removed
      | `SpecUnmatched ->
          SpecUnmatched )
  | _ ->
      [%log' debug partitioner.logger]
        "Worker submit a work that's already removed from pairing pool, \
         meaning it's completed/no longer needed, ignoring"
        ~metadata:
          [ ( "result"
            , Work.Result.Single.Poly.to_yojson
                (const `Null)
                Ledger_proof.to_yojson submitted_result )
          ] ;
      Removed

(** Submits a sub-zkapp job result to the pool. It removes the job id from
    [zkapp_jobs_sent_by_partitioner] pool.
    If the job id was present before the removal, and the pending zkapp command
    is still present in [pending_zkapp_commands], then it attempts to finalize
    the zkapp and returns [Processed None];
    If pending zkapp is not yet finalized, or invokes [submit_single] if
    finalization succeeded (also removing the pending zkapp command's record
    from the [pending_zkapp_commands]);
    If either sub-zkapp job spec or pending zkapp command aren't present,
    returns [Removed]. *)
let submit_into_pending_zkapp_command ~partitioner
    ~job_id:({ range; _ } as job_id : Work.Id.Sub_zkapp.t)
    ~data:
      ({ proof; data = elapsed } :
        (Core.Time.Span.t, Ledger_proof.t) Proof_carrying_data.t ) =
  let single_id = Work.Id.Sub_zkapp.to_single job_id in
  let finalize_zkapp_proof pending =
    match Pending_zkapp_command.try_finalize pending with
    | None ->
        Processed None
    | Some ({ job_id; _ }, proof, elapsed) ->
        [%log' debug partitioner.logger] "Finalized proof for zkapp command" ;
        partitioner.pending_zkapp_commands <-
          Single_id_map.remove partitioner.pending_zkapp_commands single_id ;
        submit_single ~is_from_zkapp:true ~partitioner
          ~submitted_result:{ spec = (); proof; elapsed }
          ~job_id
  in
  match
    ( Sent_zkapp_job_pool.remove ~id:job_id
        partitioner.zkapp_jobs_sent_by_partitioner
    , Single_id_map.find partitioner.pending_zkapp_commands single_id )
  with
  | Some { job; _ }, Some pending -> (
      match
        Pending_zkapp_command.submit_proof ~proof ~elapsed ~range pending
      with
      | Ok () ->
          Work.Metrics.emit_subzkapp_metrics ~logger:partitioner.logger
            ~sub_zkapp_spec:job.spec ~elapsed ;
          finalize_zkapp_proof pending
      | Error (`No_such_range range) ->
          [%log' debug partitioner.logger]
            "Worker submit a work that's rejected by the pending zkapp \
             command, this probably means a same subzkapp work has been \
             distributed to more than one worker"
            ~metadata:
              [ ("job_id", Work.Id.Sub_zkapp.to_yojson job_id)
              ; ("proof", Ledger_proof.to_yojson proof)
              ; ("elapsed", Mina_stdlib.Time.Span.to_yojson elapsed)
              ; ("proposed_range", Work.Id.Range.to_yojson range)
              ] ;
          SpecUnmatched )
  | None, _ | _, None ->
      [%log' debug partitioner.logger]
        "Worker submit a work that's already removed from sent sub-zkapp job \
         pool or pending zkapp command pool, meaning it's completed/no longer \
         needed, ignoring"
        ~metadata:
          [ ("job_id", Work.Id.Sub_zkapp.to_yojson job_id)
          ; ("proof", Ledger_proof.to_yojson proof)
          ; ("elapsed", Mina_stdlib.Time.Span.to_yojson elapsed)
          ] ;
      Removed

let submit_partitioned_work ~(result : Work.Result.Partitioned.Stable.Latest.t)
    ~(partitioner : t) =
  match result with
  | { id = Single job_id; data = { proof; data = elapsed } } ->
      let submitted_result =
        Work.Result.Single.Poly.{ spec = (); proof; elapsed }
      in
      submit_single ~is_from_zkapp:false ~partitioner ~submitted_result ~job_id
  | { id = Sub_zkapp job_id; data } ->
      submit_into_pending_zkapp_command ~partitioner ~job_id ~data
