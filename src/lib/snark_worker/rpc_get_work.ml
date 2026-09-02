open Async
open Core
open Snark_work_lib

(** For versioning of the types here, see:
    - RFC 0013: {:https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md}
    - {:https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html}
*)

module Master = struct
  let name = "get_work"

  module T = struct
    type query = unit

    type response = Spec.Partitioned.Stable.Latest.t option
  end

  module Caller = T
  module Callee = T
end

include Versioned_rpc.Both_convert.Plain.Make (Master)

[%%versioned_rpc
module Stable = struct
  module V5 = struct
    module T = struct
      type query = unit

      type response = Spec.Partitioned.Stable.V3.t option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    include T
    include Register (T)
  end

  (* Retained so a daemon can serve snark workers built before V3 of the spec.
     Both conversions are total: the downgrade fills the segment's sok field
     from the job's own sok message, and the upgrade drops a field that is known
     to be a placeholder.

     Retaining a version only helps if the daemon actually serves it: the RPC
     server must implement this with [implement_multi], not [Rpc.Rpc.implement]
     on a pinned [Stable.Latest.rpc]. See [Mina_run.setup_local_server].

     Note that a worker does not negotiate: [entry.ml] dispatches a pinned
     [Stable.Latest.rpc]. So this buys daemon-newer-than-worker only. A V5
     worker against a V4-only daemon still fails to get work, and daemons must
     be upgraded before workers. *)
  module V4 = struct
    module T = struct
      type query = unit

      type response = Spec.Partitioned.Stable.V2.t option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model =
        Option.map ~f:Spec.Partitioned.Stable.V2.of_v3

      let caller_model_of_response =
        Option.map ~f:Spec.Partitioned.Stable.V2.to_latest
    end

    include T
    include Register (T)
  end

  module Latest = V5
end]
