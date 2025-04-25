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
  ; mutable first_in_pair : Work.Selector.Single.Spec.t option
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
  ; first_in_pair = None
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
