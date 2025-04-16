(* work partitioner split the work produced by a Work_selector into smaller tasks,
   and issue them to the actual worker. It's also in charge of aggregating
   the response from worker. We have this layer because we don't want to
   touch the Work_selector and break the GraphQL API.

   Ideally, we should refactor so this integrates into Work_selector
*)

open Core_kernel
open Transaction_snark

type zkapp_command_work =
  | Zkapp_command_segment of
      { segment_id : int
      ; statement : Transaction_snark.Statement.With_sok.t
      ; witness : Zkapp_command_segment.Witness.t
      ; spec : Zkapp_command_segment.Basic.t
      }
  | Zkapp_command_merge of { proof1 : Ledger_proof.t; proof2 : Ledger_proof.t }

type partitioned_work =
  | Regular of
      (Transaction_witness.t, Ledger_proof.t) Snark_work_lib.Work.Single.Spec.t
  | Zkapp_command of { uuid : int; spec : zkapp_command_work }

module Single_work_with_data = struct
  type t =
    { which_half : [ `First | `Second ]
    ; proof : Ledger_proof.t
    ; metric : Core.Time.Span.t
    ; spec :
        ( Transaction_witness.t
        , Ledger_proof.t )
        Snark_work_lib.Work.Single.Spec.t
    ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
    }
end

module Pairing_id = struct
  (* Case `One` indicate no need to pair. This is needed because zkapp command
     might be left in pool of half completion. *)
  type t = First of int | Second of int | One [@@deriving compare, hash, sexp]
end

module Zkapp_command_segment_work_job = struct
  type t =
    { pairing_id : Pairing_id.t
    ; uuid : int
    ; spec : zkapp_command_work
    ; status : Work_lib.Job_status.t
    ; is_done : bool ref
    }

  let wrap_as_partitioned_work : t -> partitioned_work = fun _ -> failwith "nah"
end

module Pending_Zkapp_command = struct
  type t =
    { unseen_segments : (int, unit) Hashtbl.t
    ; pending_mergable : Ledger_proof.t Queue.t
    ; pending_base_cases :
        ( Zkapp_command_segment.Witness.t
        * Zkapp_command_segment.Basic.t
        * Statement.With_sok.t )
        Queue.t
    }
end

module State = struct
  type t =
    { reassignment_wait : int
    ; logger : Logger.t
          (* if one single work from underlying Work_selector is completed but
             not the other. throw it here. *)
    ; pairing_pool : (int, Single_work_with_data.t) Hashtbl.t
    ; zkapp_commend_segment_pool :
        (Pairing_id.t, Pending_Zkapp_command.t) Hashtbl.t
          (* we only track tasks created by a Work_partitioner here. For reissue
             of regular jobs, we still turn to the underlying Work_selector *)
          (* WARN: we're assuming everything in this queue is sorted in time from old to new.
             So queue head is the oldest task.
          *)
    ; sent_jobs_partitioner : Zkapp_command_segment_work_job.t Queue.t
          (* we mark completed tasks in this hash table instead of crossing off
             the queue `sent_jobs_partitioner`. Hence no need to iterate through
             it. *)
    ; completion_markers : (int, bool ref) Hashtbl.t
    }

  let init (reassignment_wait : int) (logger : Logger.t) : t =
    { pairing_pool = Hashtbl.create (module Int)
    ; zkapp_commend_segment_pool = Hashtbl.create (module Pairing_id)
    ; reassignment_wait
    ; logger
    ; sent_jobs_partitioner = Queue.create ()
    ; completion_markers = Hashtbl.create (module Int)
    }
end

let reissue_old_task (s : State.t) : partitioned_work option =
  let slashing_finished_task = ref true in
  let result = ref None in
  while !slashing_finished_task do
    match Queue.peek s.sent_jobs_partitioner with
    | Some { is_done; _ } when !is_done ->
        (* clearing jobs done *)
        ignore
          ( Queue.dequeue_exn s.sent_jobs_partitioner
            : Zkapp_command_segment_work_job.t )
    | Some { is_done; status; _ }
      when (not !is_done)
           && Work_lib.Job_status.is_old ~now:(Time.now ())
                ~reassignment_wait:s.reassignment_wait status ->
        (* figured out task to reissue *)
        result := Queue.dequeue s.sent_jobs_partitioner ;
        slashing_finished_task := false
    | Some _ | None ->
        (* nothing has timeout so don't reissue *)
        slashing_finished_task := false
  done ;
  let open Option.Let_syntax in
  let%map ({ uuid; spec; _ } as job) = !result in
  let reissued = { job with status = Assigned (Time.now ()) } in
  Queue.enqueue s.sent_jobs_partitioner reissued ;
  Zkapp_command { uuid; spec }
