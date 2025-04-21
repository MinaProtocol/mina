open Core
open Async
module Work = Snark_work_lib

(* For versioning of the types here, see:
   - RFC 0013: https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md
   - https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html
*)

module Rpc = struct
  module Master = struct
    let name = "submit_work"

    module T = struct
      type query = Work.Partitioned.Result.t

      (* NOTE: this `Finished case is suppoed to track all duplicated case,
         but since we didn't touch on Work_selector, this is not true.
         We should get back to Work_partitioner implementation to fix this. *)
      type response = [ `Ok | `Finished_by_others of Time.t | `Timeout ]
    end

    module Caller = T
    module Callee = T
  end

  include Master.T
  include Versioned_rpc.Both_convert.Plain.Make (Master)
end

[%%versioned_rpc
module Stable = struct
  module V3 = struct
    module T = struct
      type query = Work.Partitioned.Result.Stable.V1.t

      type response = [ `Ok | `Finished_by_others of Time.t | `Timeout ]

      let query_of_caller_model : Rpc.Master.Caller.query -> query =
        Work.Partitioned.Result.materialize

      let callee_model_of_query : query -> Rpc.Master.Callee.query =
        Work.Partitioned.Result.cache ~proof_cache_db:Proof_cache.cache_db

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    include T
    include Rpc.Register (T)
  end

  module V2 = struct
    module T = struct
      type query = Work.Selector.Result.Stable.V1.t

      type response = unit

      let query_of_caller_model (query : Rpc.Master.Caller.query) : query =
        Work.Partitioned.Result.to_selector_result query
        |> Option.value_exn
             ~message:
               "FATAL: V2 Worker completed a `Sub_zkapp_command job where the \
                coordinator can't aggregate, this shouldn't happen as the work \
                is issued by the coordinator"
        |> Work.Selector.Result.materialize

      let callee_model_of_query (query : query) : Rpc.Master.Callee.query =
        Work.Selector.Result.cache ~proof_cache_db:Proof_cache.cache_db query
        |> Work.Partitioned.Result.of_selector_result

      let response_of_callee_model = function
        | `Ok ->
            ()
        | `Finished_by_others finished_when ->
            printf
              "Trying to notify worker that the work they submitted is \
               finished by another worker at %s, but they're too old to \
               receive this message."
              (Time.to_string finished_when)
        | `Timeout ->
            printf
              "Trying to notify worker that the work they submitted is \
               timeout, but they're too old to receive this message."

      (* There's no way we can tell if the proof we submitted is duplicated/timeouted,
         just assume everything is fine on worker's side *)
      let caller_model_of_response = const `Ok
    end

    include T
    include Rpc.Register (T)
  end

  module Latest = V3
end]
