open Async
open Core
module Work = Snark_work_lib

(** For versioning of the types here, see:
    - RFC 0013: {:https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md}
    - {:https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html}
*)

module Master = struct
  let name = "submit_work"

  module T = struct
    type query = Work.Partitioned.Result.Stable.Latest.t

    type response = [ `Ok | `Slashed | `SchemeUnmatched ]
  end

  module Caller = T
  module Callee = T
end

include Versioned_rpc.Both_convert.Plain.Make (Master)

[%%versioned_rpc
module Stable = struct
  module V2 = struct
    module T = struct
      type query = Work.Selector.Result.Stable.V1.t

      type response = unit

      let query_of_caller_model (query : Master.Caller.query) : query =
        Work.Partitioned.Result.Poly.to_selector_result query
        |> Option.value_exn
             ~message:
               "FATAL: V2 Worker completed a `Sub_zkapp_command job where the \
                coordinator can't aggregate, this shouldn't happen as the work \
                is issued by the coordinator"

      let callee_model_of_query (query : query) : Master.Callee.query =
        (* Old worker can't tell when it received the job,
           so just assume it's taking 0s
        *)
        let issued_since_unix_epoch = Time.(now () |> to_span_since_epoch) in
        Work.Partitioned.Result.Poly.of_selector_result ~issued_since_unix_epoch
          query
        |> Or_error.ok
        |> Option.value_exn
             ~message:
               "Selector result has invalid shape so can't convert to \
                Partitioned result"

      let response_of_callee_model = function
        | `Ok ->
            ()
        | `Slashed ->
            printf
              "Trying to notify worker that the work they submitted is \
               slashed(completed by others, or timeouted), but they're too old \
               to receive this message."
        | `SchemeUnmatched ->
            printf
              "Trying to notify worker that the work they submitted is in a \
               wrong shape, but they're too old to receive this message."

      (* There's no way we can tell if the proof we submitted is duplicated/timeouted,
           just assume everything is fine on worker's side *)
      let caller_model_of_response = const `Ok
    end

    include T
    include Register (T)
  end

  module Latest = V2
end]
