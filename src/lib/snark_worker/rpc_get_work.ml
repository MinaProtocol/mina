(* OPAM libraries *)
open Async
open Core

(* Local libraries *)
open Signature_lib
module Work = Snark_work_lib

module Master = struct
  let name = "get_work"

  module T = struct
    type query = unit

    type response =
      (Work.Selector.Spec.Stable.Latest.t * Public_key.Compressed.t) option
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
        (Work.Selector.Spec.Stable.V1.t * Public_key.Compressed.Stable.V1.t)
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
