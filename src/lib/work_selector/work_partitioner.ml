(* work partitioner split the work produced by a Work_selector into smaller tasks,
   and issue them to the actual worker. It's also in charge of aggregating
   the response from worker. We have this layer because we don't want to
   touch the Work_selector and break the GraphQL API.

   Ideally, we should refactor so this integrates into Work_selector
*)

open Core_kernel
open Transaction_snark

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

module Pending_Zkapp_command = struct
  type t = { aggregated : Ledger_proof.t }
end

module Mergable_partition_id = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* `One_or_two` means we're receving a work not partitioned by the work partitioner *)
      type t = First of int | Second of int [@@deriving compare, hash, sexp]

      let to_latest = Fn.id
    end
  end]
end

module State = struct
  type t =
    { reassignment_wait : int
    ; logger : Logger.t
    ; pairing_pool : (int, Single_work_with_data.t) Hashtbl.t
    ; zkapp_commend_segment_pool :
        ( Mergable_partition_id.t
        , ( Zkapp_command_segment.Witness.t
          * Zkapp_command_segment.Basic.t
          * Statement.With_sok.t )
          Queue.t )
        Hashtbl.t
    }

  let init (reassignment_wait : int) (logger : Logger.t) : t =
    { pairing_pool = Hashtbl.create (module Int)
    ; zkapp_commend_segment_pool = Hashtbl.create (module Mergable_partition_id)
    ; reassignment_wait
    ; logger
    }
end
