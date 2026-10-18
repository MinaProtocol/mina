open Async
open Core
open Snark_work_lib

(** For versioning of the types here, see:
    - RFC 0013: {:https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md}
    - {:https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html}
*)

module Master = struct
  let name = "submit_work"

  module T = struct
    type query = Result.Partitioned.Stable.Latest.t

    (* For more details, see Work_partitioner.Work_partitioner *)
    type response =
      [ `SpecUnmatched
        (** The submitted result doesn't match up with the spec in pool. For 
            example, the partitioner requires first/second in a pair, but the 
            worker responded with a unpaired result. This should only happen 
            when there's a bug in worker.  *)
      | `Removed
        (** The partitioner already removed the work spec from its pool, meaning
            it's already completed by another worker or no longer needed. It's 
            safe to ignore this error and continue polling partitioner for other
            work specs. *)
      | `Ok
        (** The partitioner successfully accepts work into its internal states. *)
      ]
  end

  module Caller = T
  module Callee = T
end

include Versioned_rpc.Both_convert.Plain.Make (Master)

[%%versioned_rpc
module Stable = struct
  module V3 = struct
    module T = struct
      type query = Result.Partitioned.Stable.V1.t

      type response = [ `SpecUnmatched | `Removed | `Ok ]

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    include T
    include Register (T)
  end

  module Latest = V3
end]
