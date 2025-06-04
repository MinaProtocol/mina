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

    type response =
      ( Selector.Spec.Stable.Latest.t
      * Signature_lib.Public_key.Compressed.Stable.Latest.t )
      option
  end

  module Caller = T
  module Callee = T
end

include Versioned_rpc.Both_convert.Plain.Make (Master)

[%%versioned_rpc
module Stable = struct
  module V2 = struct
    module T = struct
      type query = unit

      type response =
        ( Selector.Spec.Stable.V1.t
        * Signature_lib.Public_key.Compressed.Stable.V1.t )
        option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    include T
    include Register (T)
  end

  module Latest = V2
end]
