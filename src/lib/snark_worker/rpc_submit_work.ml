(* External Libraries *)
open Async

(* Local Libraries *)
module Work = Snark_work_lib

module Master = struct
  let name = "submit_work"

  module T = struct
    type query = Work.Selector.Result.t

    type response = unit
  end

  module Caller = T
  module Callee = T
end

include Versioned_rpc.Both_convert.Plain.Make (Master)
