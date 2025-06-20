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
  ; subzkapp_id_gen : Id_generator.t
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
    ~(proof_cache_db : Proof_cache_tag.cache_db) : t =
  let module M = Transaction_snark.Make (struct
    let constraint_constants = Genesis_constants.Compiled.constraint_constants

    let proof_level = Genesis_constants.Compiled.proof_level
  end) in
  { logger
  ; transaction_snark = (module M)
  ; single_id_gen = Id_generator.create ~logger
  ; subzkapp_id_gen = Id_generator.create ~logger
  ; pairing_pool = Hashtbl.create (module Int64)
  ; pending_zkapp_commands = Single_id_map.empty
  ; reassignment_timeout
  ; zkapp_jobs_sent_by_partitioner = Sent_zkapp_job_pool.create ()
  ; single_jobs_sent_by_partitioner = Sent_single_job_pool.create ()
  ; tmp_slot = None
  ; proof_cache_db
  }

let epoch_now () = Time.(now () |> to_span_since_epoch)

(* TODO: Consider remove all works no longer relevant for current frontier,
   this may need changes from underlying work selector. *)
let reschedule_if_old ~logger ~spec_to_yojson ~reassignment_timeout
    (job : _ Work.With_job_meta.Stable.Latest.t) =
  let scheduled = Time.of_span_since_epoch job.scheduled_since_unix_epoch in
  let now = Time.now () in
  let elapsed_since_last_schedule = Time.diff now scheduled in
  if Time.Span.( > ) elapsed_since_last_schedule reassignment_timeout then (
    [%log warn] "Rescheduling old job $job"
      ~metadata:
        [ ("job", spec_to_yojson job.spec)
        ; ( "scheduled"
          , Mina_stdlib.Time.Span.to_yojson job.scheduled_since_unix_epoch )
        ; ( "now"
          , Mina_stdlib.Time.Span.to_yojson (now |> Time.to_span_since_epoch) )
        ; ( "elapsed_since_last_schedule"
          , Mina_stdlib.Time.Span.to_yojson elapsed_since_last_schedule )
        ; ( "reassignment_timeout"
          , Mina_stdlib.Time.Span.to_yojson reassignment_timeout )
        ] ;
    `Stop_reschedule
      Work.With_job_meta.Stable.Latest.
        { job with scheduled_since_unix_epoch = epoch_now () } )
  else `Stop_keep

(* NOTE: below are logics for work requesting *)
let reschedule_old_zkapp_job
    ~partitioner:
      ({ reassignment_timeout; zkapp_jobs_sent_by_partitioner; logger; _ } : t)
    : Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
  let%map.Option job =
    Sent_zkapp_job_pool.remove_until_reschedule
      ~f:
        (reschedule_if_old ~logger
           ~spec_to_yojson:Work.Spec.Sub_zkapp.Stable.Latest.to_yojson
           ~reassignment_timeout )
      zkapp_jobs_sent_by_partitioner
  in
  Ok (Work.Spec.Partitioned.Poly.Sub_zkapp_command { job; data = () })

let reschedule_old_single_job
    ~partitioner:
      ({ reassignment_timeout; single_jobs_sent_by_partitioner; logger; _ } : t)
    : Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
  let%map.Option job =
    Sent_single_job_pool.remove_until_reschedule
      ~f:
        (reschedule_if_old ~logger
           ~spec_to_yojson:Work.Spec.Single.Stable.Latest.to_yojson
           ~reassignment_timeout )
      single_jobs_sent_by_partitioner
  in
  Ok (Work.Spec.Partitioned.Poly.Single { job; data = () })

let register_pending_zkapp_command_job ~(id : Work.Id.Single.t)
    ~(partitioner : t) ~sub_zkapp_spec ~(pending : Pending_zkapp_command.t) =
  let job_id =
    Work.Id.Sub_zkapp.of_single
      ~job_id:(Id_generator.next_id partitioner.subzkapp_id_gen ())
      id
  in
  let job =
    Work.With_job_meta.
      { spec = sub_zkapp_spec
      ; job_id
      ; scheduled_since_unix_epoch = epoch_now ()
      ; sok_message = (Pending_zkapp_command.zkapp_job pending).sok_message
      }
  in
  Sent_zkapp_job_pool.add_exn ~id:job_id ~job
    ~message:
      "Work Partitioner generated a duplicated ID for a subzkapp job that \
       happens to be still used by another job."
    partitioner.zkapp_jobs_sent_by_partitioner ;

  Work.Spec.Partitioned.Poly.Sub_zkapp_command { job; data = () }

let schedule_from_pending_zkapp_command ~(id : Work.Id.Single.t)
    ~(partitioner : t) (pending : Pending_zkapp_command.t) =
  let%map.Option sub_zkapp_spec =
    Pending_zkapp_command.next_subzkapp_job_spec pending
  in
  register_pending_zkapp_command_job ~id ~partitioner ~sub_zkapp_spec ~pending

let schedule_from_any_pending_zkapp_command ~(partitioner : t) :
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
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
    |> Mina_stdlib.Nonempty_list.mapi
         ~f:(fun which_segment (witness, spec, statement) ->
           Work.Spec.Sub_zkapp.Stable.Latest.Segment
             { statement; witness; spec; which_segment } )
  in
  let pending_zkapp_command, first_segment =
    Pending_zkapp_command.create_and_yield_segment ~job ~unscheduled_segments
  in
  partitioner.pending_zkapp_commands <-
    Single_id_map.add_exn ~key:pairing ~data:pending_zkapp_command
      partitioner.pending_zkapp_commands ;
  register_pending_zkapp_command_job ~id:pairing ~partitioner
    ~sub_zkapp_spec:first_segment ~pending:pending_zkapp_command

let convert_single_work_from_selector ~(partitioner : t)
    ~(single_spec : Work.Spec.Single.t) ~sok_message ~pairing :
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t =
  let job =
    Work.With_job_meta.
      { spec = single_spec
      ; job_id = pairing
      ; scheduled_since_unix_epoch = epoch_now ()
      ; sok_message
      }
  in
  match single_spec with
  | Transition (input, witness) -> (
      match witness.transaction with
      | Command (Zkapp_command zkapp_command) ->
          (* TODO: we have read from disk followed by write to disk in shared
             function followed by read from disk again. Should consider refactor
             this. *)
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
          Sent_single_job_pool.add_exn ~id:pairing ~job
            ~message:
              "Id generator generated a repeated Id that happens to be \
               occupied by a job in sent single job pool"
            partitioner.single_jobs_sent_by_partitioner ;
          Ok (Single { job; data = () }) )
  | Merge _ ->
      let job =
        Work.With_job_meta.map
          ~f_spec:Work.Spec.Single.read_all_proofs_from_disk job
      in
      Sent_single_job_pool.add_exn ~id:pairing ~job
        ~message:
          "Id generator generated a repeated Id that happens to be occupied by \
           a job in sent single job pool"
        partitioner.single_jobs_sent_by_partitioner ;
      Ok (Single { job; data = () })

let schedule_from_tmp_slot ~(partitioner : t) =
  let%map.Option spec = partitioner.tmp_slot in
  partitioner.tmp_slot <- None ;
  let single_spec, pairing, sok_message = spec in
  convert_single_work_from_selector ~partitioner ~single_spec ~pairing
    ~sok_message

let schedule_job_from_partitioner ~(partitioner : t) :
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
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
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t =
  let pairing_id = Id_generator.next_id partitioner.single_id_gen () in
  Hashtbl.add_exn partitioner.pairing_pool ~key:pairing_id
    ~data:(Spec_only { spec = instances; sok_message }) ;

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
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
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
  let submitted_result_cached =
    Snark_work_lib.Result.Single.Poly.map ~f_spec:Fn.id
      ~f_proof:
        (Ledger_proof.Cached.write_proof_to_disk
           ~proof_cache_db:partitioner.proof_cache_db )
      submitted_result
  in
  match
    Combining_result.merge_single_result combining_result
      ~logger:partitioner.logger ~submitted_result:submitted_result_cached
      ~submitted_half
  with
  | Pending new_combining_result ->
      `Pending new_combining_result
  | Done combined ->
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
    If it's from zkapp, don't check reschedule because it's never in sent single
    job pool in the first place. *)
let submit_single ?is_from_zkapp ~partitioner
    ~(submitted_result : (unit, Ledger_proof.t) Work.Result.Single.Poly.t)
    ~job_id () =
  let Work.Id.Single.{ which_one = submitted_half; pairing_id } = job_id in
  match
    ( Sent_single_job_pool.remove ~id:job_id
        partitioner.single_jobs_sent_by_partitioner
    , Hashtbl.find partitioner.pairing_pool pairing_id
    , is_from_zkapp )
  with
  | (None as removed_job), Some combining_result, Some true
  | (Some _ as removed_job), Some combining_result, _ -> (
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
          Option.iter removed_job ~f:(fun job ->
              Sent_single_job_pool.bring_back ~id:job_id ~job
                partitioner.single_jobs_sent_by_partitioner ) ;
          SpecUnmatched )
  | _ ->
      [%log' debug partitioner.logger]
        "Worker submit a work that's already removed from pairing pool, \
         meaning it's completed/no longer needed, ignoring"
        ~metadata:
          [ ( "result"
            , Work.Result.Single.Poly.to_yojson
                (fun () -> `Null)
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
    ~(job_id : Work.Id.Sub_zkapp.t)
    ~data:
      ({ proof; data = elapsed } as data :
        (Core.Time.Span.t, Ledger_proof.t) Proof_carrying_data.t ) =
  let single_id = Work.Id.Sub_zkapp.to_single job_id in
  match
    ( Sent_zkapp_job_pool.remove ~id:job_id
        partitioner.zkapp_jobs_sent_by_partitioner
    , Single_id_map.find partitioner.pending_zkapp_commands single_id )
  with
  | Some job, Some pending -> (
      let range = Work.Spec.Sub_zkapp.Stable.Latest.get_range job.spec in
      Work.Spec.Partitioned.Poly.Stable.Latest.Sub_zkapp_command { job; data }
      |> Work.Metrics.emit_partitioned_metrics ~logger:partitioner.logger ;
      match
        Pending_zkapp_command.submit_proof ~proof ~elapsed ~range pending
      with
      | Ok () -> (
          match Pending_zkapp_command.try_finalize pending with
          | None ->
              Processed None
          | Some ({ job_id; _ }, proof, elapsed) ->
              [%log' debug partitioner.logger] "Finalized zkapp" ;
              partitioner.pending_zkapp_commands <-
                Single_id_map.remove partitioner.pending_zkapp_commands
                  single_id ;
              submit_single ~is_from_zkapp:true ~partitioner
                ~submitted_result:{ spec = (); proof; elapsed }
                ~job_id () )
      | Error _ ->
          Sent_zkapp_job_pool.bring_back ~id:job_id ~job
            partitioner.zkapp_jobs_sent_by_partitioner ;
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
  | Work.Spec.Partitioned.Poly.Single
      { job = Work.With_job_meta.{ job_id; spec; _ }
      ; data = { proof; data = elapsed }
      } ->
      let submitted_result = Work.Result.Single.Poly.{ spec; proof; elapsed } in
      submit_single ~partitioner ~submitted_result ~job_id ()
  | Work.Spec.Partitioned.Poly.Sub_zkapp_command
      { job = Work.With_job_meta.{ job_id; _ }; data } ->
      submit_into_pending_zkapp_command ~partitioner ~job_id ~data
