(* work partitioner split the work produced by a Work_selector into smaller tasks,
   and issue them to the actual worker. It's also in charge of aggregating
   the response from worker. We have this layer because we don't want to
   touch the Work_selector and break the GraphQL API.

   Ideally, we should refactor so this integrates into Work_selector
*)

open Core_kernel
open Transaction_snark

type partitioned_work =
  | Regular of
      (Transaction_witness.t, Ledger_proof.t) Snark_work_lib.Work.Single.Spec.t
  | Zkapp_command_segment of
      { segment_id : int
      ; statement : Transaction_snark.Statement.With_sok.t
      ; witness : Zkapp_command_segment.Witness.t
      ; spec : Zkapp_command_segment.Basic.t
      }

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

module Mergable_partition_id = struct
  (* `One_or_two` means we're receving a work not partitioned by the work partitioner *)
  type t = First of int | Second of int [@@deriving compare, hash, sexp]
end

module Zkapp_command_segment_work_job = struct
  type t =
    { id : Mergable_partition_id.t
    ; spec :
        [ `Merge_segment of Ledger_proof.t * Ledger_proof.t
        | `Base_segment of
          Zkapp_command_segment.Witness.t
          * Zkapp_command_segment.Basic.t
          * Statement.With_sok.t ]
    ; status : Work_lib.Job_status.t
    }
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
    ; pairing_pool : (int, Single_work_with_data.t) Hashtbl.t
    ; zkapp_commend_segment_pool :
        (Mergable_partition_id.t, Pending_Zkapp_command.t) Hashtbl.t
    ; sent_jobs_partitioner : Zkapp_command_segment_work_job.t Queue.t
          (* we only track tasks created by a Work_partitioner here. For reissue of regular jobs,
             we still turn to the underlying Work_selector *)
    }

  let init (reassignment_wait : int) (logger : Logger.t) : t =
    { pairing_pool = Hashtbl.create (module Int)
    ; zkapp_commend_segment_pool = Hashtbl.create (module Mergable_partition_id)
    ; reassignment_wait
    ; logger
    ; sent_jobs_partitioner = Queue.create ()
    }
end
