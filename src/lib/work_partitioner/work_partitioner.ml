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
  | Some (id, job_with_status) ->
      let issued_since_unix_epoch = Time.(now () |> to_span_since_epoch) in
      let reissued =
        { job_with_status with
          common = { job_with_status.common with issued_since_unix_epoch }
        }
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
  let issued_since_unix_epoch = Time.(now () |> to_span_since_epoch) in
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
