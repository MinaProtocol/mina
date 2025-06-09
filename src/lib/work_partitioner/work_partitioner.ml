open Core_kernel

open struct
  module Work = Snark_work_lib
end

module Snark_worker_shared = Snark_worker_shared
module Zkapp_command_job_pool =
  Job_pool.Make (Work.Id.Single) (Pending_zkapp_command)
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
  ; zkapp_command_jobs : Zkapp_command_job_pool.t
  ; reassignment_timeout : Time.Span.t
  ; zkapp_jobs_sent_by_partitioner : Sent_zkapp_job_pool.t
  ; single_jobs_sent_by_partitioner : Sent_single_job_pool.t
  ; mutable tmp_slot :
      (Work.Spec.Single.t * Work.Id.Single.t * Mina_base.Sok_message.t) option
        (** When receving a `Two works from the underlying Work_selector, store
            one of them here, so we could schedule them to another worker. *)
  }

let create ~(reassignment_timeout : Time.Span.t) ~(logger : Logger.t) : t =
  let module M = Transaction_snark.Make (struct
    let constraint_constants = Genesis_constants.Compiled.constraint_constants

    let proof_level = Genesis_constants.Compiled.proof_level
  end) in
  { logger
  ; transaction_snark = (module M)
  ; single_id_gen = Id_generator.create ~logger
  ; subzkapp_id_gen = Id_generator.create ~logger
  ; pairing_pool = Hashtbl.create (module Int64)
  ; zkapp_command_jobs = Zkapp_command_job_pool.create ()
  ; reassignment_timeout
  ; zkapp_jobs_sent_by_partitioner = Sent_zkapp_job_pool.create ()
  ; single_jobs_sent_by_partitioner = Sent_single_job_pool.create ()
  ; tmp_slot = None
  }

let epoch_now () = Time.(now () |> to_span_since_epoch)

let reschedule_if_old ~reassignment_timeout
    (job : _ Work.With_job_meta.Stable.Latest.t) =
  let scheduled = Time.of_span_since_epoch job.scheduled_since_unix_epoch in
  let delta = Time.(diff (now ()) scheduled) in
  if Time.Span.( > ) delta reassignment_timeout then
    `Stop_reschedule
      Work.With_job_meta.Stable.Latest.
        { job with scheduled_since_unix_epoch = epoch_now () }
  else `Stop_keep

(* NOTE: below are logics for work requesting *)
let reschedule_old_zkapp_job
    ~partitioner:
      ({ reassignment_timeout; zkapp_jobs_sent_by_partitioner; _ } : t) () :
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
  let%map.Option job =
    Sent_zkapp_job_pool.remove_until_reschedule
      ~f:(reschedule_if_old ~reassignment_timeout)
      zkapp_jobs_sent_by_partitioner
  in

  Ok (Work.Spec.Partitioned.Poly.Sub_zkapp_command { job; data = () })

let reschedule_old_single_job
    ~partitioner:
      ({ reassignment_timeout; single_jobs_sent_by_partitioner; _ } : t) () :
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
  let%map.Option job =
    Sent_single_job_pool.remove_until_reschedule
      ~f:(reschedule_if_old ~reassignment_timeout)
      single_jobs_sent_by_partitioner
  in
  Ok (Work.Spec.Partitioned.Poly.Single { job; data = () })

let register_pending_zkapp_command_job ~(partitioner : t) ~sub_zkapp_spec
    ({ job_id = zkapp_id; sok_message; _ } : Zkapp_command_job_pool.job) =
  let job_id =
    Work.Id.Sub_zkapp.of_single
      ~job_id:(Id_generator.next_id partitioner.subzkapp_id_gen ())
      zkapp_id
  in
  let job =
    Work.With_job_meta.
      { spec = sub_zkapp_spec
      ; job_id
      ; scheduled_since_unix_epoch = epoch_now ()
      ; sok_message
      }
  in
  assert (
    phys_equal `Ok
      (Sent_zkapp_job_pool.add ~id:job_id ~job
         partitioner.zkapp_jobs_sent_by_partitioner ) ) ;

  Work.Spec.Partitioned.Poly.Sub_zkapp_command { job; data = () }

let schedule_from_pending_zkapp_command ~(partitioner : t)
    ({ spec = pending; _ } as job : Zkapp_command_job_pool.job) =
  let%map.Option sub_zkapp_spec = Pending_zkapp_command.next_job_spec pending in
  register_pending_zkapp_command_job ~partitioner ~sub_zkapp_spec job

let schedule_from_zkapp_command_work_pool ~(partitioner : t) () :
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
  let%map.Option job =
    Zkapp_command_job_pool.iter_until
      ~f:(schedule_from_pending_zkapp_command ~partitioner)
      partitioner.zkapp_command_jobs
  in
  Ok job

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
          let witness = Transaction_witness.read_all_proofs_from_disk witness in
          Snark_worker_shared.extract_zkapp_segment_works
            ~m:partitioner.transaction_snark ~input ~witness ~zkapp_command
          |> Result.map ~f:(function
               | first_segment :: rest_segments ->
                   let unscheduled_segments =
                     Mina_stdlib.Nonempty_list.(
                       init first_segment rest_segments
                       |> map ~f:(fun (witness, spec, statement) ->
                              Work.Spec.Sub_zkapp.Segment
                                { statement; witness; spec }
                              |> Work.Spec.Sub_zkapp.read_all_proofs_from_disk ))
                   in
                   let pending_zkapp_command, first_segment =
                     Pending_zkapp_command.create_and_yield_segment ~job
                       ~unscheduled_segments
                   in
                   let pending_zkapp_command_job =
                     Work.With_job_meta.
                       { spec = pending_zkapp_command
                       ; job_id = pairing
                       ; scheduled_since_unix_epoch = epoch_now ()
                       ; sok_message
                       }
                   in
                   Zkapp_command_job_pool.add_exn ~id:pairing
                     ~job:pending_zkapp_command_job
                     ~message:
                       "Id generater generated a repeated Id that happens to \
                        be occupied by a job in zkapp command pool"
                     partitioner.zkapp_command_jobs ;
                   register_pending_zkapp_command_job ~partitioner
                     ~sub_zkapp_spec:first_segment pending_zkapp_command_job
               | [] ->
                   (* TODO: erase this branch by refactor underlying
                      [Transaction_snark.zkapp_command_witnesses_exn] using nonempty
                      list *)
                   failwith "No witness generated" )
      | Command (Signed_command _) | Fee_transfer _ | Coinbase _ ->
          let job =
            Work.With_job_meta.map
              ~f_spec:Work.Spec.Single.read_all_proofs_from_disk job
          in
          Ok (Single { job; data = () }) )
  | Merge _ ->
      let job =
        Work.With_job_meta.map
          ~f_spec:Work.Spec.Single.read_all_proofs_from_disk job
      in
      Ok (Single { job; data = () })

let schedule_from_tmp_slot ~(partitioner : t) () =
  match partitioner.tmp_slot with
  | Some spec ->
      partitioner.tmp_slot <- None ;
      let single_spec, pairing, sok_message = spec in
      Some
        (convert_single_work_from_selector ~partitioner ~single_spec ~pairing
           ~sok_message )
  | None ->
      None

let schedule_job_from_partitioner ~(partitioner : t) () :
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ reschedule_old_zkapp_job ~partitioner
    ; reschedule_old_single_job ~partitioner
    ; schedule_from_zkapp_command_work_pool ~partitioner
    ; schedule_from_tmp_slot ~partitioner
    ]

(* WARN: this should only be called if [partitioner.tmp_slot] is None *)
let consume_job_from_selector ~(partitioner : t)
    ~(sok_message : Mina_base.Sok_message.t)
    ~(instances : Work.Spec.Single.t One_or_two.t) () :
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
      assert (phys_equal None partitioner.tmp_slot) ;
      let pairing1 : Work.Id.Single.t = { which_one = `First; pairing_id } in
      let pairing2 : Work.Id.Single.t = { which_one = `Second; pairing_id } in
      partitioner.tmp_slot <- Some (spec1, pairing1, sok_message) ;
      convert_single_work_from_selector ~partitioner ~single_spec:spec2
        ~sok_message ~pairing:pairing2

type work_from_selector = unit -> Work.Spec.Single.t One_or_two.t option

let request_from_selector_and_consume_by_partitioner ~(partitioner : t)
    ~(work_from_selector : work_from_selector)
    ~(sok_message : Mina_base.Sok_message.t) () =
  let%map.Option instances = work_from_selector () in

  consume_job_from_selector ~partitioner ~instances ~sok_message ()

let request_partitioned_work ~(sok_message : Mina_base.Sok_message.t)
    ~(work_from_selector : work_from_selector) ~(partitioner : t) :
    Work.Spec.Partitioned.Stable.Latest.t Or_error.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ schedule_job_from_partitioner ~partitioner
    ; request_from_selector_and_consume_by_partitioner ~partitioner
        ~work_from_selector ~sok_message
    ]
