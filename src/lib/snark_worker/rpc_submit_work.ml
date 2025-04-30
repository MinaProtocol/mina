(* OPAM libraries *)
open Async
open Core

(* Local libraries *)
module Work = Snark_work_lib

module Master = struct
  let name = "submit_work"

  module T = struct
    type query = Work.Selector.Result.Stable.Latest.t

    type response = unit
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
